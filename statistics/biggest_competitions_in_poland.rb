require_relative "../core/statistic"

class BiggestCompetitionsInPoland < Statistic
  def initialize
    @title = "Biggest competitions in Poland"
    @note = "Every competitor with at least one result is counted, no matter their country."
    @table_header = { "Competitors" => :right, "Competition" => :left }
  end

  def query
    <<-SQL
      SELECT
        competitors_count,
        CONCAT('[', competition.cell_name, '](https://www.worldcubeassociation.org/competitions/', competition.id, ')') competition
      FROM (
        SELECT
          COUNT(DISTINCT person_id) competitors_count,
          competition_id
        FROM results
        GROUP BY competition_id
      ) AS competitors_count_by_competition
      JOIN competitions competition ON competition.id = competition_id AND competition.country_id = 'Poland'
      ORDER BY competitors_count DESC, competition.start_date
      LIMIT 50
    SQL
  end
end
