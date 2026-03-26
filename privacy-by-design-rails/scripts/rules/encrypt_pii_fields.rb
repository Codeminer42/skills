# rules/encrypt_pii_fields.rb
require_relative "base_rule"
require_relative "../utils/pii_patterns"

class EncryptPiiFields < BaseRule
  def self.pii_column?(name, markets: [])
    PiiPatterns.pii_field?(name, markets: markets)
  end

  def initialize
    @name = "encrypt-pii-fields"
    @impact = "critical"
    @description = "Every column storing personal data must use Active Record Encryption"
    @schema = nil
    @markets = []
  end

  attr_writer :markets

  # Pre-scan: receive parsed schema from the scanner
  def pre_scan(_files, _read_file_proc, schema: nil)
    @schema = schema
  end

  def applies_to?(file_path)
    file_path.match?(%r{app/models/.*\.rb$}) || file_path.match?(%r{db/migrate/.*\.rb$})
  end

  def check(file_path, content)
    if file_path.match?(%r{db/migrate/})
      check_migration(file_path, content)
    else
      check_model(file_path, content)
    end
  end

  private

  def check_migration(file_path, content)
    findings = []
    table_name = extract_table_name(content)

    content.each_line.with_index(1) do |line, line_num|
      match = line.match(/t\.(string|text|integer|date|datetime|decimal)\s+:(\w+)/)
      next unless match

      column_name = match[2]
      next if PiiPatterns::BCRYPT_FIELDS.include?(column_name)
      next unless PiiPatterns.pii_field?(column_name, markets: @markets)

      # Skip if we have schema info and the column doesn't exist in the current schema
      if @schema && table_name
        next unless @schema.column_exists?(table_name, column_name)
      end

      findings << finding(
        file: file_path,
        line: line_num,
        message: "Column :#{column_name} appears to be PII but has no encryption. Add `encrypts :#{column_name}` to the model.",
        confidence: PiiPatterns.pii_confidence(column_name),
        snippet: line.strip,
        suggestion: "encrypts :#{column_name}"
      )
    end
    findings
  end

  def extract_table_name(content)
    if (match = content.match(/create_table\s+:(\w+)/))
      match[1]
    elsif (match = content.match(/create_table\s+"(\w+)"/))
      match[1]
    elsif (match = content.match(/add_column\s+:(\w+)/))
      match[1]
    elsif (match = content.match(/add_column\s+"(\w+)"/))
      match[1]
    end
  end

  def check_model(file_path, content)
    encrypted_fields = content.scan(/encrypts\s+:(\w+)/).flatten
    findings = []

    content.each_line.with_index(1) do |line, line_num|
      match = line.match(/(?:attr_accessor|attribute)\s+:(\w+)/)
      next unless match

      field = match[1]
      next if PiiPatterns::BCRYPT_FIELDS.include?(field)
      next unless PiiPatterns.pii_field?(field, markets: @markets)
      next if encrypted_fields.include?(field)

      findings << finding(
        file: file_path,
        line: line_num,
        message: "Attribute :#{field} appears to be PII but has no `encrypts` declaration.",
        confidence: PiiPatterns.pii_confidence(field),
        snippet: line.strip,
        suggestion: "encrypts :#{field}"
      )
    end
    findings
  end
end
