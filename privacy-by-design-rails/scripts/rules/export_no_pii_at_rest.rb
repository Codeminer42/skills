# rules/export_no_pii_at_rest.rb
require_relative "base_rule"

class ExportNoPiiAtRest < BaseRule
  STORAGE_PATTERNS = [
    /\.update!\(.*metadata.*export/m,
    /\.update\(.*metadata.*export/m,
    /metadata\s*[\[:].*export/,
    /\.update!\(.*:?\s*export\b/
  ].freeze

  def initialize
    @name = "export-no-pii-at-rest"
    @impact = "medium"
    @description = "Generate exports on-demand, never store decrypted PII"
  end

  def applies_to?(file_path)
    file_path.match?(%r{app/serializers/.*\.rb$}) ||
      file_path.match?(%r{app/controllers/.*\.rb$}) ||
      file_path.match?(%r{app/jobs/.*\.rb$})
  end

  def check(file_path, content)
    findings = []

    content.each_line.with_index(1) do |line, line_num|
      # Look for patterns that store serialized export data in DB columns
      if line.match?(/\.update.*metadata.*export|metadata\[.*export/) ||
         (line.include?("Serializer") && line.match?(/\.update|\.save/))
        # Check surrounding context (3 lines)
        block_start = [line_num - 3, 0].max
        block_end = [line_num + 3, content.lines.size].min
        block = content.lines[block_start...block_end].join

        if block.match?(/Serializer.*\.as_json|\.to_json/) && block.match?(/update|save|metadata/)
          findings << finding(
            file: file_path,
            line: line_num,
            message: "Export data appears to be stored in a database column. Generate exports on-demand instead — storing decrypted PII defeats encryption at rest.",
            confidence: "medium",
            snippet: line.strip,
            suggestion: "Generate the export on-demand in the controller when the user requests it"
          )
        end
      end
    end
    findings
  end
end
