require_relative "../core/statistic"

class MostRoundsAtCompetition < Statistic
  def initialize
    @title = "Most rounds held at a competition"
    @table_header = { "Rounds" => :right, "Competition" => :left }
  end

  def query
    <<-SQL
      SELECT
        total_rounds,
        CONCAT('[', competition.cell_name, '](https://www.worldcubeassociation.org/competitions/', competition.id, ')') competition_link
      FROM (
        SELECT competition_id, COUNT(*) total_rounds
        FROM (
          SELECT DISTINCT competition_id, event_id, round_type_id
          FROM results
        ) AS distinct_rounds
        GROUP BY competition_id
      ) AS round_counts
      JOIN competitions competition ON competition.id = competition_id
      WHERE competition.country_id = 'Poland'
      ORDER BY total_rounds DESC
      LIMIT 50
    SQL
  end

  def transform(query_results)
    query_results.map do |result|
      [result["total_rounds"], result["competition_link"]]
    end
  end
end
