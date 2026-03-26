# rules/consent_use_purposes_constant.rb
require_relative "base_rule"

class ConsentUsePurposesConstant < BaseRule
  def initialize
    @name = "consent-use-purposes-constant"
    @impact = "medium"
    @description = "Use Consent::PURPOSES for consent purposes, not free-form strings"
  end

  def applies_to?(file_path)
    file_path.match?(%r{app/models/consent\.rb$}) ||
      file_path.match?(%r{app/controllers/.*\.rb$})
  end

  def check(file_path, content)
    if file_path.match?(%r{app/models/consent\.rb$})
      check_model(file_path, content)
    else
      check_controller(file_path, content)
    end
  end

  private

  def check_model(file_path, content)
    return [] if content.include?("PURPOSES")

    class_line = content.each_line.with_index(1) do |line, num|
      break num if line.match?(/class\s+Consent/)
    end

    [finding(
      file: file_path,
      line: class_line.is_a?(Integer) ? class_line : 1,
      message: "Consent model has no PURPOSES constant. Define `PURPOSES = %w[...].freeze` and validate inclusion to prevent invalid purpose strings.",
      confidence: "high",
      snippet: "class Consent < ApplicationRecord",
      suggestion: 'PURPOSES = %w[order_processing marketing analytics third_party_sharing].freeze'
    )]
  end

  def check_controller(file_path, content)
    return [] unless content.match?(/consent|grant_consent/i)

    findings = []
    content.each_line.with_index(1) do |line, line_num|
      # Detect string literals passed as consent purposes (not referencing PURPOSES constant)
      if line.match?(/grant_consent!\s*\(?\s*["']/) || line.match?(/purpose:\s*["']/)
        unless line.include?("PURPOSES")
          findings << finding(
            file: file_path,
            line: line_num,
            message: "Consent purpose is a free-form string. Use `Consent::PURPOSES` constant to ensure valid purposes.",
            confidence: "high",
            snippet: line.strip,
            suggestion: "Use Consent::PURPOSES values instead of string literals"
          )
        end
      end
    end
    findings
  end
end
