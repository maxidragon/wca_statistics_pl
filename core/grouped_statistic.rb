require_relative "statistic"

class GroupedStatistic < Statistic
  def markdown
    markdown = top
    # A group may pass its own table header as a third element and a description as a fourth.
    data.each do |header, subdata, table_header = @table_header, description = nil|
      unless subdata.empty?
        markdown += "\n### #{header}\n\n"
        markdown += "#{description}\n\n" if description
        markdown += markdown_table(table_header, subdata)
      end
    end
    markdown
  end
end
