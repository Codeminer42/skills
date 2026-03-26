# utils/changed_files.rb

class ChangedFiles
  PRIVACY_PATTERNS = [
    %r{^app/models/.*\.rb$},
    %r{^app/jobs/.*\.rb$},
    %r{^app/workers/.*\.rb$},
    %r{^app/sidekiq/.*\.rb$},
    %r{^app/mailers/.*\.rb$},
    %r{^app/views/.*mailer.*\.(erb|haml|slim)$},
    %r{^app/controllers/.*\.rb$},
    %r{^app/serializers/.*\.rb$},
    %r{^app/services/.*\.rb$},
    %r{^config/initializers/filter_parameter_logging\.rb$},
    %r{^config/initializers/.*\.rb$},
    %r{^config/environments/production\.rb$},
    %r{^config/recurring\.yml$},
    %r{^db/migrate/.*\.rb$},
    %r{^db/schema\.rb$},
    %r{^Gemfile$}
  ].freeze

  EXCLUDE_PATTERNS = [
    %r{^(test|spec)/},
    %r{^vendor/}
  ].freeze

  # Returns changed files + related files that should be checked together.
  # A changed migration pulls in its model and filter_parameter_logging.rb, etc.
  # Also returns a breakdown: { changed: [...], related: [...], all: [...] }
  def self.from_git
    changed = git_changed_files
    related = []

    changed.each do |file|
      related.concat(find_related_files(file))
    end

    all = (changed + related).uniq.select { |f| File.exist?(f) }

    {
      changed: changed,
      related: all - changed,
      all: all
    }
  end

  def self.all_in_project
    Dir.glob("**/*.{rb,erb,haml,slim,yml}").select { |f| privacy_relevant?(f) } +
      (File.exist?("Gemfile") ? ["Gemfile"] : [])
  end

  def self.privacy_relevant?(file_path)
    return false if EXCLUDE_PATTERNS.any? { |p| file_path.match?(p) }

    PRIVACY_PATTERNS.any? { |p| file_path.match?(p) }
  end

  private

  def self.git_changed_files
    unstaged = `git diff --name-only HEAD 2>/dev/null`.strip.split("\n")
    staged = `git diff --name-only --cached 2>/dev/null`.strip.split("\n")
    (unstaged + staged).uniq.select { |f| privacy_relevant?(f) }
  end

  # Given a changed file, return related files that should also be scanned.
  def self.find_related_files(file_path)
    related = []

    # Always include filter_parameter_logging.rb and schema when touching models or migrations
    if file_path.match?(%r{^(app/models/|db/migrate/)})
      related << "config/initializers/filter_parameter_logging.rb"
      related << "db/schema.rb"
    end

    # Migration → pull in corresponding model
    if (match = file_path.match(%r{^db/migrate/.*_create_(\w+)\.rb$}))
      table_name = match[1]
      model_name = table_name.sub(/s$/, "") # naive singularize
      related << "app/models/#{model_name}.rb"
    elsif (match = file_path.match(%r{^db/migrate/.*_add_\w+_to_(\w+)\.rb$}))
      table_name = match[1]
      model_name = table_name.sub(/s$/, "")
      related << "app/models/#{model_name}.rb"
    end

    # Model → pull in mailers that reference this model
    if (match = file_path.match(%r{^app/models/(\w+)\.rb$}))
      model_name = match[1]
      Dir.glob("app/mailers/**/*.rb").each do |mailer|
        content = File.read(mailer) rescue nil
        related << mailer if content&.match?(/#{model_name}/i)
      end
    end

    # Mailer class → pull in its templates
    if (match = file_path.match(%r{^app/mailers/(\w+)\.rb$}))
      mailer_name = match[1].sub(/_mailer$/, "")
      Dir.glob("app/views/#{mailer_name}_mailer/**/*.{erb,haml,slim}").each do |tpl|
        related << tpl
      end
      Dir.glob("app/views/#{mailer_name}/**/*.{erb,haml,slim}").each do |tpl|
        related << tpl
      end
    end

    # Mailer template → pull in its mailer class
    if (match = file_path.match(%r{^app/views/(\w+_mailer)/}))
      related << "app/mailers/#{match[1]}.rb"
    elsif (match = file_path.match(%r{^app/views/(\w+)/.*mailer}))
      related << "app/mailers/#{match[1]}_mailer.rb"
    end

    # Job/worker → pull in ApplicationJob (to check log_arguments inheritance)
    if file_path.match?(%r{^app/(jobs|workers|sidekiq)/}) && !file_path.match?(/application_job/)
      related << "app/jobs/application_job.rb"
    end

    # Controller → pull in related model if it's clearly a resource controller
    if (match = file_path.match(%r{^app/controllers/(.*/)?(\w+)_controller\.rb$}))
      model_name = match[2].sub(/s$/, "")
      related << "app/models/#{model_name}.rb"
    end

    related
  end
end
