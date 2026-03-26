# rules/log_no_job_arguments.rb
require_relative "base_rule"

class LogNoJobArguments < BaseRule
  SIDEKIQ_PATTERN = /Sidekiq::(Worker|Job)/

  def initialize
    @name = "log-no-job-arguments"
    @impact = "high"
    @description = "Jobs handling personal data must suppress argument logging"
  end

  def applies_to?(file_path)
    file_path.match?(%r{app/(jobs|workers|sidekiq)/.*\.rb$})
  end

  def check(file_path, content)
    class_match = content.match(/class\s+(\w+)\s*</)
    return [] unless class_match

    class_name = class_match[1]

    # Skip jobs with no perform method or parameterless perform — no arguments to leak
    return [] unless content.match?(/def perform/)
    return [] if content.match?(/def perform\s*$/) || content.match?(/def perform\s*\(\s*\)/)

    is_sidekiq = content.match?(SIDEKIQ_PATTERN)

    # Flag if log_arguments is not explicitly set to false in this file.
    # The deep-dive analysis will handle inheritance (base class already sets it).
    return [] if content.include?("self.log_arguments = false")

    # Flag explicit re-enabling as high-confidence
    if content.include?("self.log_arguments = true")
      return [finding(
        file: file_path,
        line: find_class_line(content, class_name),
        message: "#{class_name} explicitly re-enables argument logging with `self.log_arguments = true`.",
        confidence: "high",
        snippet: "self.log_arguments = true",
        suggestion: "Remove `self.log_arguments = true` unless you are certain this job never handles PII."
      )]
    end

    confidence = is_sidekiq ? "medium" : "high"
    suggestion = if is_sidekiq
      "Pass only record IDs in perform arguments. Consider switching to ActiveJob with Sidekiq adapter for `self.log_arguments = false` support."
    else
      "self.log_arguments = false"
    end

    [finding(
      file: file_path,
      line: find_class_line(content, class_name),
      message: "#{class_name} does not set `self.log_arguments = false`. Job arguments may leak PII into logs.",
      confidence: confidence,
      snippet: class_match[0],
      suggestion: suggestion
    )]
  end

  private

  def find_class_line(content, class_name)
    line_num = content.each_line.with_index(1) do |line, num|
      break num if line.match?(/class\s+#{class_name}/)
    end
    line_num.is_a?(Integer) ? line_num : 1
  end
end
