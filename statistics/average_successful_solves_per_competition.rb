require_relative "../core/statistic"

class AverageSuccessfulSolvesPerCompetition < Statistic
  MIN_COMPETITIONS = 20

  def initialize
    @title = "Average number of successful solves per competition"
    @note = "Counts successful individual attempts (value > 0). DNS and empty attempts are excluded. Minimum #{MIN_COMPETITIONS} competitions required."
    @table_header = { "Person" => :left, "Avg. successful" => :right, "Total successful" => :right, "Competitions" => :right }
  end

  def query
    <<-SQL
      SELECT
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link,
        ROUND(AVG(successful_solves), 2) avg_successful,
        SUM(successful_solves) total_successful,
        COUNT(*) competitions
      FROM (
        SELECT
          r.person_id,
          r.competition_id,
          SUM(CASE WHEN ra.value > 0 THEN 1 ELSE 0 END) successful_solves
        FROM results r
        JOIN result_attempts ra ON ra.result_id = r.id
        WHERE ra.value != 0 AND ra.value != -2
        GROUP BY r.person_id, r.competition_id
      ) AS per_competition
      JOIN persons person ON person.wca_id = person_id AND person.sub_id = 1 AND person.country_id = 'Poland'
      GROUP BY person_id, person_link
      HAVING competitions >= #{MIN_COMPETITIONS}
      ORDER BY avg_successful DESC
      LIMIT 50
    SQL
  end

  def transform(query_results)
    query_results.map do |result|
      [result["person_link"], format("%.2f", result["avg_successful"]), result["total_successful"].to_i, result["competitions"]]
    end
  end
end
