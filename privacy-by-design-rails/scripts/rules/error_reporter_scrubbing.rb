# rules/error_reporter_scrubbing.rb
require_relative "base_rule"

class ErrorReporterScrubbing < BaseRule
  # Known error reporter gems and their config patterns
  REPORTERS = {
    "rollbar" => {
      pattern: /Rollbar\.configure/,
      scrub_check: /scrub_fields|anonymize_user_ip/,
      person_check: /person_username_method\s*=\s*nil|person_email_method\s*=\s*nil/
    },
    "sentry" => {
      pattern: /Sentry\.init|Raven\.configure/,
      scrub_check: /before_send|sanitize_fields|send_default_pii\s*=\s*false/,
      person_check: nil
    },
    "bugsnag" => {
      pattern: /Bugsnag\.configure/,
      scrub_check: /before_notify|redacted_keys|meta_data_filters/,
      person_check: nil
    },
    "honeybadger" => {
      pattern: /Honeybadger\.configure/,
      scrub_check: /before_notify|params_filters/,
      person_check: nil
    },
    "airbrake" => {
      pattern: /Airbrake\.configure/,
      scrub_check: /add_filter|blocklist_keys/,
      person_check: nil
    }
  }.freeze

  def initialize
    @name = "error-reporter-scrubbing"
    @impact = "critical"
    @description = "Error reporters must scrub PII before sending to external services"
  end

  def applies_to?(file_path)
    file_path.match?(%r{config/initializers/.*\.rb$})
  end

  def check(file_path, content)
    findings = []

    REPORTERS.each do |reporter_name, config|
      next unless content.match?(config[:pattern])

      has_scrubbing = content.match?(config[:scrub_check])

      unless has_scrubbing
        findings << finding(
          file: file_path,
          line: find_config_line(content, config[:pattern]),
          message: "#{reporter_name.capitalize} is configured without PII scrubbing. Request parameters containing PII are sent to #{reporter_name.capitalize}'s external servers.",
          confidence: "high",
          snippet: content.lines.find { |l| l.match?(config[:pattern]) }&.strip || "",
          suggestion: "Add scrub_fields/before_send and anonymize_user_ip to #{reporter_name.capitalize} configuration"
        )
      end

      # Check if person identification sends PII (Rollbar-specific)
      if config[:person_check] && content.match?(/person_username_method|person_email_method/)
        unless content.match?(config[:person_check])
          findings << finding(
            file: file_path,
            line: find_config_line(content, /person_/),
            message: "#{reporter_name.capitalize} sends user name/email as person identification. Only send user ID.",
            confidence: "high",
            snippet: content.lines.find { |l| l.match?(/person_/) }&.strip || "",
            suggestion: "Set person_username_method = nil and person_email_method = nil"
          )
        end
      end
    end

    findings
  end

  private

  def find_config_line(content, pattern)
    content.each_line.with_index(1) do |line, num|
      return num if line.match?(pattern)
    end
    1
  end
end
