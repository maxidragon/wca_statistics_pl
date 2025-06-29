require_relative "../core/statistic"

class LongestCompetitions < Statistic
  def initialize
    @title = "Longest competitions in Poland"
    @table_header = { "Days" => :right, "Competition" => :left }
  end

  def query
    <<-SQL
      SELECT (DATEDIFF(end_date, start_date) + 1) AS days, name
      FROM competitions
      WHERE country_id = "Poland" AND results_posted_at IS NOT null
      HAVING days >= 3
      ORDER BY days desc;
    SQL
  end
end
