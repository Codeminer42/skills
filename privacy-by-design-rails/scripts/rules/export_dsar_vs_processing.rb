# rules/export_dsar_vs_processing.rb
require_relative "base_rule"

class ExportDsarVsProcessing < BaseRule
  def initialize
    @name = "export-dsar-vs-processing"
    @impact = "medium"
    @description = "Use the correct serializer for DSAR vs processing exports"
  end

  def applies_to?(file_path)
    file_path.match?(%r{app/controllers/.*\.rb$}) ||
      file_path.match?(%r{app/serializers/.*\.rb$})
  end

  def check(file_path, content)
    findings = []

    # Detect consent-gated serializer used in DSAR context
    if dsar_context?(file_path, content) && content.include?("ConsentGatedExportSerializer")
      content.each_line.with_index(1) do |line, line_num|
        if line.include?("ConsentGatedExportSerializer")
          findings << finding(
            file: file_path,
            line: line_num,
            message: "DSAR access must return all personal data. ConsentGatedExportSerializer gates by consent — use DataExportSerializer for DSAR responses.",
            confidence: "high",
            snippet: line.strip,
            suggestion: "DataExportSerializer.new(user).as_json"
          )
        end
      end
    end

    findings
  end

  private

  def dsar_context?(file_path, content)
    file_path.match?(/data_subject_request|dsar|data_export/i) ||
      content.match?(/data_subject_request|dsar|right.of.access/i)
  end
end
