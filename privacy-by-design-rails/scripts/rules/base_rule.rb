# rules/base_rule.rb
Finding = Struct.new(:rule, :impact, :file, :line, :message, :confidence, :snippet, :suggestion, keyword_init: true) do
  def to_h
    super.transform_keys(&:to_s)
  end
end

class BaseRule
  attr_reader :name, :impact, :description

  def check(file_path, content)
    raise NotImplementedError, "#{self.class}#check not implemented"
  end

  def applies_to?(file_path)
    raise NotImplementedError, "#{self.class}#applies_to? not implemented"
  end

  private

  def finding(file:, line:, message:, confidence:, snippet:, suggestion:)
    Finding.new(
      rule: name,
      impact: impact,
      file: file,
      line: line,
      message: message,
      confidence: confidence,
      snippet: snippet,
      suggestion: suggestion
    )
  end
end
