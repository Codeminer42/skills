# rules/minimize_ransackable_attributes.rb
require_relative "base_rule"
require_relative "../utils/pii_patterns"

class MinimizeRansackableAttributes < BaseRule
  # Security-sensitive fields that should NEVER be searchable
  SECURITY_FIELDS = %w[
    encrypted_password
    password_digest
    reset_password_token
    reset_password_sent_at
    unlock_token
    confirmation_token
    remember_token
    otp_secret
    otp_backup_codes
    session_token
  ].freeze

  def initialize
    @name = "minimize-ransackable-attributes"
    @impact = "high"
    @description = "Sensitive fields should not be exposed through ransackable_attributes"
    @markets = []
  end

  attr_writer :markets

  def applies_to?(file_path)
    file_path.match?(%r{app/models/.*\.rb$})
  end

  def check(file_path, content)
    return [] unless content.match?(/ransackable_attributes/)

    # Extract the returned array from ransackable_attributes method
    attrs = extract_ransackable_attrs(content)
    return [] if attrs.empty?

    findings = []
    line_num = find_ransackable_line(content)

    # Check for security-sensitive fields
    security_exposed = attrs & SECURITY_FIELDS
    unless security_exposed.empty?
      findings << finding(
        file: file_path,
        line: line_num,
        message: "ransackable_attributes exposes security-sensitive fields: #{security_exposed.join(', ')}. These should never be searchable.",
        confidence: "high",
        snippet: "ransackable_attributes includes #{security_exposed.join(', ')}",
        suggestion: "Remove #{security_exposed.join(', ')} from ransackable_attributes"
      )
    end

    # Check for PII fields
    pii_exposed = attrs.select { |attr| PiiPatterns.pii_field?(attr, markets: @markets) }
    unless pii_exposed.empty?
      findings << finding(
        file: file_path,
        line: line_num,
        message: "ransackable_attributes exposes PII fields: #{pii_exposed.join(', ')}. Review whether admin search on these is strictly necessary.",
        confidence: "medium",
        snippet: "ransackable_attributes includes #{pii_exposed.join(', ')}",
        suggestion: "Remove PII fields from ransackable_attributes unless search is essential"
      )
    end

    findings
  end

  private

  def extract_ransackable_attrs(content)
    # Match %w[...] or %w(...)
    if (match = content.match(/ransackable_attributes.*?(%w[\[\(]([^\]\)]+)[\]\)])/m))
      match[2].split
    # Match [...] with quoted strings
    elsif (match = content.match(/ransackable_attributes.*?\[([^\]]+)\]/m))
      match[1].scan(/["'](\w+)["']/).flatten
    else
      []
    end
  end

  def find_ransackable_line(content)
    content.each_line.with_index(1) do |line, num|
      return num if line.match?(/ransackable_attributes/)
    end
    1
  end
end
