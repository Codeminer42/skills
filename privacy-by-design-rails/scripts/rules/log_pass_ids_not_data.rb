# rules/log_pass_ids_not_data.rb
require_relative "base_rule"
require_relative "../utils/pii_patterns"

class LogPassIdsNotData < BaseRule
  def initialize
    @name = "log-pass-ids-not-data"
    @impact = "high"
    @description = "Pass IDs to jobs, never PII data"
    @markets = []
  end

  attr_writer :markets

  def applies_to?(file_path)
    file_path.match?(%r{app/(jobs|workers|sidekiq)/.*\.rb$})
  end

  def check(file_path, content)
    perform_match = content.match(/def perform\(([^)]*)\)/m)
    return [] unless perform_match

    params_str = perform_match[1]
    perform_line = content.each_line.with_index(1) do |line, num|
      break num if line.include?("def perform")
    end

    findings = []
    params_str.scan(/[\s,]?:?(\w+)[:\s,]?/).flatten.each do |param|
      param = param.strip.delete(":")
      next if param.empty? || param.end_with?("_id") || param == "id"

      if PiiPatterns.pii_field?(param, markets: @markets)
        findings << finding(
          file: file_path,
          line: perform_line.is_a?(Integer) ? perform_line : 1,
          message: "Job parameter :#{param} appears to be PII. Pass an ID instead and look up the record inside the job.",
          confidence: "high",
          snippet: "def perform(#{params_str.strip})",
          suggestion: "Pass the record's ID instead: def perform(#{param.sub(/email|name|phone|address/, "user")}_id)"
        )
      end
    end
    findings
  end
end
