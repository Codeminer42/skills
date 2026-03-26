# rules/email_no_pii_in_body.rb
require_relative "base_rule"
require_relative "../utils/pii_patterns"

class EmailNoPiiInBody < BaseRule
  def initialize
    @name = "email-no-pii-in-body"
    @impact = "high"
    @description = "Never include PII in email bodies"
    @markets = []
  end

  attr_writer :markets

  def applies_to?(file_path)
    file_path.match?(%r{app/mailers/.*\.rb$}) ||
      file_path.match?(%r{app/views/.*mailer.*\.(erb|haml|slim)$})
  end

  def check(file_path, content)
    if file_path.match?(/\.erb$|\.haml$|\.slim$/)
      check_template(file_path, content)
    else
      check_mailer(file_path, content)
    end
  end

  private

  def pii_accessors
    @pii_accessors ||= PiiPatterns.all_patterns(markets: @markets)
  end

  def check_template(file_path, content)
    findings = []

    content.each_line.with_index(1) do |line, line_num|
      pii_accessors.each do |accessor|
        if line.match?(/<%=.*\.#{accessor}\b/)
          findings << finding(
            file: file_path,
            line: line_num,
            message: "Email template references .#{accessor} — PII in email bodies persists in inboxes indefinitely.",
            confidence: "high",
            snippet: line.strip,
            suggestion: "Send a link back to the app instead of including PII directly"
          )
        end
      end
    end
    findings
  end

  def check_mailer(file_path, content)
    findings = []
    pii_pattern = pii_accessors.join("|")

    content.each_line.with_index(1) do |line, line_num|
      # Detect assigning PII to instance variables (which get passed to templates)
      pii_accessors.each do |accessor|
        if line.match?(/@\w+\s*=.*\.#{accessor}\b/)
          findings << finding(
            file: file_path,
            line: line_num,
            message: "Mailer assigns .#{accessor} to an instance variable — this PII will appear in the email body.",
            confidence: "high",
            snippet: line.strip,
            suggestion: "Send a link (e.g., using MessageVerifier) instead of the PII data"
          )
        end
      end

      # Detect PII in from: argument (user email exposed to recipients)
      if line.match?(/\bfrom:\s.*\.(#{pii_pattern})\b/)
        findings << finding(
          file: file_path,
          line: line_num,
          message: "Mailer uses PII as the `from:` address. The user's personal data is exposed to all recipients and persists in their inboxes.",
          confidence: "high",
          snippet: line.strip,
          suggestion: "Use a no-reply address (e.g., ENV['MAILER_SENDER']) instead of the user's email."
        )
      end

      # Detect PII in subject: argument (visible in inbox previews and notifications)
      if line.match?(/\bsubject:.*\.(#{pii_pattern})\b/) || line.match?(/\bsubject:.*\#\{.*\.(#{pii_pattern})\b/)
        findings << finding(
          file: file_path,
          line: line_num,
          message: "Email subject line contains PII. Subjects are visible in inbox previews and notification banners.",
          confidence: "high",
          snippet: line.strip,
          suggestion: "Remove PII from email subject lines. Use generic descriptions instead."
        )
      end
    end
    findings
  end
end
