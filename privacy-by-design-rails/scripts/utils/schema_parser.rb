# utils/schema_parser.rb
require "set"

class SchemaParser
  attr_reader :columns

  def initialize
    @columns = {} # { "table_name" => Set["col1", "col2"] }
  end

  def parse(content)
    return unless content

    current_table = nil
    content.each_line do |line|
      if (table_match = line.match(/create_table\s+"(\w+)"/))
        current_table = table_match[1]
        @columns[current_table] = Set.new
      elsif current_table && (col_match = line.match(/t\.\w+\s+"(\w+)"/))
        @columns[current_table] << col_match[1]
      end
    end
    self
  end

  def table_exists?(table_name)
    @columns.key?(table_name)
  end

  def column_exists?(table_name, column_name)
    @columns[table_name]&.include?(column_name)
  end

  def empty?
    @columns.empty?
  end
end
