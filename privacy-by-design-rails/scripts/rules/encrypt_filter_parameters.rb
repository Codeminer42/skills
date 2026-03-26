# rules/encrypt_filter_parameters.rb
require_relative "base_rule"
require_relative "../utils/pii_patterns"

class EncryptFilterParameters < BaseRule
  def initialize
    @name = "encrypt-filter-parameters"
    @impact = "critical"
    @description = "PII fields must be declared in both config.filter_parameters and model filter_attributes"
    @schema = nil
    @markets = []
  end

  attr_writer :markets

  # Pre-scan: receive parsed schema to know which PII fields exist
  def pre_scan(_files, _read_file_proc, schema: nil)
    @schema = schema
  end

  def applies_to?(file_path)
    file_path.match?(%r{app/models/.*\.rb$}) ||
      file_path.match?(%r{config/initializers/filter_parameter_logging\.rb$})
  end

  def check(file_path, content)
    if file_path.match?(%r{app/models/})
      check_model(file_path, content)
    elsif file_path.match?(%r{filter_parameter_logging})
      check_filter_params_initializer(file_path, content)
    else
      []
    end
  end

  private

  def check_model(file_path, content)
    encrypted_fields = content.scan(/encrypts\s+:(\w+)/).flatten
    return [] if encrypted_fields.empty?

    findings = []

    unless content.include?("self.filter_attributes")
      findings << finding(
        file: file_path,
        line: find_class_line(content),
        message: "Model uses `encrypts` but does not declare `self.filter_attributes`. PII may leak in #inspect and error reporters.",
        confidence: "high",
        snippet: "encrypts :#{encrypted_fields.first}",
        suggestion: "self.filter_attributes = %i[#{encrypted_fields.join(" ")}]"
      )
    end

    findings
  end

  def check_filter_params_initializer(file_path, content)
    return [] if @schema.nil? || @schema.empty?

    # Collect all PII field names from the schema
    all_pii_fields = []
    @schema.columns.each do |_table, columns|
      columns.each do |col|
        all_pii_fields << col if PiiPatterns.pii_field?(col, markets: @markets)
      end
    end
    all_pii_fields.uniq!

    return [] if all_pii_fields.empty?

    # Extract declared filter_parameters from the initializer
    declared = extract_declared_params(content)

    # Find PII fields not covered by filter_parameters
    # filter_parameters uses partial matching, so :email matches email_address
    missing = all_pii_fields.reject do |field|
      declared.any? { |param| field == param || field.include?(param) || param.include?(field) }
    end

    return [] if missing.empty?

    [finding(
      file: file_path,
      line: find_filter_line(content),
      message: "filter_parameters is missing PII fields: #{missing.sort.join(', ')}. These appear in plaintext in logs and error reporters.",
      confidence: "high",
      snippet: content.lines.find { |l| l.match?(/filter_parameters/) }&.strip || "",
      suggestion: "Add to filter_parameters: #{missing.sort.map { |f| ":#{f}" }.join(', ')}"
    )]
  end

  def extract_declared_params(content)
    # Match symbols in filter_parameters += [...] or += %i[...]
    params = []
    content.scan(/:(\w+)/).each { |match| params << match[0] }
    content.scan(/%i\[([^\]]+)\]/).each do |match|
      match[0].split.each { |p| params << p }
    end
    params.uniq
  end

  def find_class_line(content)
    content.each_line.with_index(1) do |line, num|
      return num if line.match?(/class\s+\w+/)
    end
    1
  end

  def find_filter_line(content)
    content.each_line.with_index(1) do |line, num|
      return num if line.match?(/filter_parameters/)
    end
    1
  end
end
