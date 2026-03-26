# rules/log_no_pii_in_cache.rb
require_relative "base_rule"

class LogNoPiiInCache < BaseRule
  # Patterns that suggest caching a full ActiveRecord object
  SUSPECT_PATTERNS = [
    /Rails\.cache\.(?:fetch|write)\(.*\)\s*\{[^}]*\.find/,
    /Rails\.cache\.(?:fetch|write)\(.*\)\s*\{\s*\w+\s*\}/,
    /Rails\.cache\.(?:fetch|write)\(.*,\s*\w+\)/
  ].freeze

  # Patterns that suggest caching safe scalar data
  SAFE_PATTERNS = [
    /\.count\b/,
    /\.size\b/,
    /\.length\b/,
    /\.sum\b/,
    /\.maximum\b/,
    /\.minimum\b/,
    /\.average\b/,
    /\.pluck\b/,
    /\.ids\b/
  ].freeze

  def initialize
    @name = "log-no-pii-in-cache"
    @impact = "high"
    @description = "Never cache objects containing PII"
  end

  def applies_to?(file_path)
    file_path.match?(/\.rb$/)
  end

  def check(file_path, content)
    return [] unless content.include?("Rails.cache")

    findings = []
    content.each_line.with_index(1) do |line, line_num|
      next unless line.include?("Rails.cache")

      # Get the cache block (current line + next few lines for multiline)
      block_end = [line_num + 3, content.lines.size].min
      block = content.lines[(line_num - 1)...block_end].join

      next if SAFE_PATTERNS.any? { |p| block.match?(p) }

      if SUSPECT_PATTERNS.any? { |p| block.match?(p) }
        findings << finding(
          file: file_path,
          line: line_num,
          message: "Cache call may store a full ActiveRecord object containing PII. Cache only non-sensitive scalar data.",
          confidence: "medium",
          snippet: line.strip,
          suggestion: "Cache only non-sensitive data: Rails.cache.fetch(key) { record.non_pii_field }"
        )
      end
    end
    findings
  end
end
