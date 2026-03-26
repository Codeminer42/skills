# scanner.rb
require "json"
require "time"
require_relative "rules/base_rule"
require_relative "rules/encrypt_pii_fields"
require_relative "rules/encrypt_filter_parameters"
require_relative "rules/log_no_job_arguments"
require_relative "rules/log_pass_ids_not_data"
require_relative "rules/log_no_pii_in_cache"
require_relative "rules/email_no_pii_in_body"
require_relative "rules/consent_use_purposes_constant"
require_relative "rules/export_dsar_vs_processing"
require_relative "rules/export_no_pii_at_rest"
require_relative "rules/minimize_ransackable_attributes"
require_relative "rules/error_reporter_scrubbing"
require_relative "utils/changed_files"
require_relative "utils/schema_parser"
require_relative "utils/pii_patterns"

class Scanner
  RULES = [
    EncryptPiiFields.new,
    EncryptFilterParameters.new,
    LogNoJobArguments.new,
    LogPassIdsNotData.new,
    LogNoPiiInCache.new,
    EmailNoPiiInBody.new,
    ConsentUsePurposesConstant.new,
    ExportDsarVsProcessing.new,
    ExportNoPiiAtRest.new,
    MinimizeRansackableAttributes.new,
    ErrorReporterScrubbing.new
  ].freeze

  SEVERITY_ORDER = { "critical" => 0, "high" => 1, "medium" => 2 }.freeze

  attr_reader :scan_type

  def initialize(files: nil, changed_only: false, content_override: {}, markets: [])
    @content_override = content_override
    @markets = markets

    @changed_files = []
    @related_files = []

    if !content_override.empty?
      @files = content_override.keys
      @scan_type = "files"
    elsif files
      @files = files
      @scan_type = "files"
    elsif changed_only
      result = ChangedFiles.from_git
      @changed_files = result[:changed]
      @related_files = result[:related]
      @files = result[:all]
      @scan_type = "changed_only"
    else
      @files = ChangedFiles.all_in_project
      @scan_type = "full"
    end
  end

  def run
    findings = []

    # Parse schema once, share with all rules
    @schema = parse_schema

    # Set markets on rules that support it
    RULES.each do |rule|
      rule.markets = @markets if rule.respond_to?(:markets=)
    end

    # Pre-scan phase: let rules that need global context inspect files first
    read_proc = method(:read_file)
    RULES.each do |rule|
      if rule.respond_to?(:pre_scan)
        rule.pre_scan(@files, read_proc, schema: @schema)
      end
    end

    @files.each do |file_path|
      content = read_file(file_path)
      next unless content

      RULES.each do |rule|
        next unless rule.applies_to?(file_path)
        findings.concat(rule.check(file_path, content))
      end
    end

    sorted = findings.sort_by { |f| SEVERITY_ORDER.fetch(f.impact, 99) }

    result = {
      "scan_type" => scan_type,
      "timestamp" => Time.now.utc.iso8601,
      "files_scanned" => @files.size,
      "markets" => @markets,
      "summary" => build_summary(sorted),
      "findings" => sorted.map(&:to_h),
      "checklist" => build_checklist(sorted),
      "inventory" => build_inventory
    }

    # In changed_only mode, include the file breakdown
    if scan_type == "changed_only"
      result["changed_files"] = @changed_files.sort
      result["related_files"] = @related_files.sort
    end

    result
  end

  def self.error_json(message)
    {
      "error" => message,
      "scan_type" => nil,
      "timestamp" => Time.now.utc.iso8601,
      "files_scanned" => 0,
      "summary" => { "critical" => 0, "high" => 0, "medium" => 0, "total" => 0 },
      "findings" => [],
      "checklist" => {}
    }
  end

  private

  def parse_schema
    schema_file = @files.find { |f| f.end_with?("db/schema.rb") }
    schema_file ||= "db/schema.rb" if File.exist?("db/schema.rb")
    return SchemaParser.new unless schema_file

    content = read_file(schema_file)
    return SchemaParser.new unless content

    SchemaParser.new.parse(content)
  end

  def read_file(file_path)
    return @content_override[file_path] if @content_override.key?(file_path)
    return nil unless File.exist?(file_path)
    File.read(file_path)
  rescue => e
    nil
  end

  def build_summary(findings)
    counts = findings.group_by(&:impact).transform_values(&:size)
    {
      "critical" => counts.fetch("critical", 0),
      "high" => counts.fetch("high", 0),
      "medium" => counts.fetch("medium", 0),
      "total" => findings.size
    }
  end

  def build_checklist(findings)
    rules_with_findings = findings.map(&:rule).uniq

    {
      "all_pii_encrypted" => !rules_with_findings.include?("encrypt-pii-fields"),
      "filter_parameters_complete" => !rules_with_findings.include?("encrypt-filter-parameters") || checklist_filter_params_ok?(findings),
      "filter_attributes_on_models" => !findings.any? { |f| f.rule == "encrypt-filter-parameters" && f.message.include?("filter_attributes") },
      "job_arguments_suppressed" => !rules_with_findings.include?("log-no-job-arguments"),
      "no_pii_in_job_payloads" => !rules_with_findings.include?("log-pass-ids-not-data"),
      "no_pii_in_email_bodies" => !rules_with_findings.include?("email-no-pii-in-body"),
      "no_pii_in_cache" => !rules_with_findings.include?("log-no-pii-in-cache"),
      "consent_purposes_constant" => checklist_consent_purposes,
      "requires_consent_enforcement" => checklist_requires_consent,
      "dsar_workflow_complete" => checklist_dsar_workflow,
      "exports_on_demand" => checklist_exports_on_demand(rules_with_findings),
      "dsar_vs_processing_separated" => checklist_dsar_vs_processing,
      "force_ssl_enabled" => checklist_force_ssl,
      "logstop_configured" => checklist_gem_present?("logstop"),
      "ip_anonymization" => checklist_gem_present?("ip_anonymizer"),
      "error_reporter_scrubbing" => checklist_error_reporter_scrubbing,
      "data_retention_scheduled" => checklist_data_retention,
      "security_audit_gems" => checklist_gem_present?("bundler-audit") && checklist_gem_present?("brakeman")
    }
  end

  def checklist_filter_params_ok?(findings)
    !findings.any? { |f| f.rule == "encrypt-filter-parameters" && f.message.include?("filter_parameters") }
  end

  def checklist_consent_purposes
    return nil unless File.exist?("app/models/consent.rb")
    File.read("app/models/consent.rb").include?("PURPOSES")
  rescue
    nil
  end

  def checklist_requires_consent
    return nil unless File.exist?("app/models/consent.rb")
    Dir.glob("app/controllers/**/*.rb").any? { |f| File.read(f).include?("RequiresConsent") }
  rescue
    nil
  end

  def checklist_dsar_workflow
    return nil unless File.exist?("app/models/data_subject_request.rb")
    has_job = Dir.glob("app/jobs/**/*.rb").any? { |f| File.read(f).match?(/data_subject_request/i) }
    has_controller = Dir.glob("app/controllers/**/*.rb").any? { |f| File.read(f).match?(/data_subject_request/i) }
    has_job && has_controller
  rescue
    nil
  end

  def checklist_dsar_vs_processing
    serializers = Dir.glob("app/serializers/**/*.rb")
    return nil if serializers.empty?
    has_export = serializers.any? { |f| f.match?(/data_export/i) }
    has_consent_gated = serializers.any? { |f| f.match?(/consent_gated/i) }
    has_export && has_consent_gated
  rescue
    nil
  end

  def checklist_exports_on_demand(rules_with_findings)
    serializers = Dir.glob("app/serializers/**/*.rb")
    return nil if serializers.empty?
    !rules_with_findings.include?("export-no-pii-at-rest")
  rescue
    nil
  end

  def checklist_force_ssl
    return false unless File.exist?("config/environments/production.rb")
    content = File.read("config/environments/production.rb")
    # Must be uncommented — ignore `# config.force_ssl = true`
    content.match?(/^\s*config\.force_ssl\s*=\s*true/)
  rescue
    false
  end

  def checklist_gem_present?(gem_name)
    return false unless File.exist?("Gemfile")
    File.read("Gemfile").match?(/gem\s+['"]#{gem_name}['"]/)
  rescue
    false
  end

  def checklist_error_reporter_scrubbing
    initializers = Dir.glob("config/initializers/**/*.rb")
    return nil if initializers.empty?
    initializers.any? { |f| content = File.read(f); content.match?(/sentry|rollbar|bugsnag/i) && content.match?(/before_send|scrub|filter/i) }
  rescue
    nil
  end

  def checklist_data_retention
    return nil unless File.exist?("config/recurring.yml")
    content = File.read("config/recurring.yml")
    content.match?(/retention|cleanup|purge/i)
  rescue
    nil
  end

  # --- Inventory methods ---

  def build_inventory
    {
      "models" => Dir.glob("app/models/**/*.rb").sort,
      "mailers" => Dir.glob("app/mailers/**/*.rb").sort,
      "mailer_templates" => Dir.glob("app/views/**/*mailer*/**/*.{erb,haml,slim}").sort,
      "jobs" => (Dir.glob("app/jobs/**/*.rb") + Dir.glob("app/workers/**/*.rb") + Dir.glob("app/sidekiq/**/*.rb")).sort,
      "controllers" => Dir.glob("app/controllers/**/*.rb").sort,
      "services" => Dir.glob("app/services/**/*.rb").sort,
      "initializers" => Dir.glob("config/initializers/*.rb").sort,
      "schema_tables_with_pii" => discover_pii_tables,
      "ransackable_models" => discover_ransackable_models,
      "audit_declarations" => discover_audit_declarations,
      "external_api_calls" => discover_external_api_calls,
      "json_endpoints" => discover_json_endpoints
    }
  end

  def discover_pii_tables
    return {} if @schema.nil? || @schema.empty?

    pii_tables = {}
    @schema.columns.each do |table, columns|
      pii_cols = columns.select { |col| PiiPatterns.pii_field?(col, markets: @markets) }
      pii_tables[table] = pii_cols.to_a.sort unless pii_cols.empty?
    end
    pii_tables
  end

  def discover_ransackable_models
    Dir.glob("app/models/**/*.rb").select do |f|
      content = read_file(f)
      content&.match?(/ransackable_attributes/)
    end.sort
  end

  def discover_audit_declarations
    Dir.glob("app/models/**/*.rb").each_with_object({}) do |f, results|
      content = read_file(f)
      next unless content
      if content.match?(/\baudited\b|has_paper_trail|PaperTrail|Logidze/)
        model_name = File.basename(f, ".rb")
        results[model_name] = f
      end
    end
  end

  def discover_external_api_calls
    pattern = /Net::HTTP|HTTParty|Faraday|RestClient|URI\.open/
    results = []
    (Dir.glob("app/**/*.rb") + Dir.glob("lib/**/*.rb")).each do |f|
      content = read_file(f)
      next unless content
      content.each_line.with_index(1) do |line, num|
        results << "#{f}:#{num}" if line.match?(pattern)
      end
    end
    results.sort
  end

  def discover_json_endpoints
    results = []
    Dir.glob("app/controllers/**/*.rb").each do |f|
      content = read_file(f)
      next unless content
      content.each_line.with_index(1) do |line, num|
        results << "#{f}:#{num}" if line.match?(/render\s+json:/)
      end
    end
    results.sort
  end
end

# CLI entry point
if __FILE__ == $0
  def parse_markets(argv)
    return [] unless argv.include?("--markets")
    idx = argv.index("--markets") + 1
    return [] if idx >= argv.size
    argv[idx].split(",").map(&:strip)
  end

  begin
    mode_flags = ARGV & ["--changed-only", "--files"]
    if mode_flags.size > 1
      puts JSON.pretty_generate(Scanner.error_json("Conflicting flags: #{mode_flags.join(', ')} are mutually exclusive"))
      exit 1
    end

    markets = parse_markets(ARGV)

    if ARGV.include?("--changed-only")
      scanner = Scanner.new(changed_only: true, markets: markets)
    elsif ARGV.include?("--files")
      file_index = ARGV.index("--files") + 1
      files = ARGV[file_index..].reject { |a| a.start_with?("--") }
      scanner = Scanner.new(files: files, markets: markets)
    else
      scanner = Scanner.new(markets: markets)
    end

    puts JSON.pretty_generate(scanner.run)
    exit 0
  rescue => e
    puts JSON.pretty_generate(Scanner.error_json(e.message))
    exit 1
  end
end
