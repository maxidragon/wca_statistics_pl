require_relative "../core/statistic"

class HighestPercentageOfCompetitionsWithMedal < Statistic
  def initialize
    @title = "Highest percentage of competitions with at least one medal"
    @note = "A medal means a top 3 place in a final of any event. Only Polish competitors with at least 10 competitions are included."
    @table_header = { "Share" => :right, "With a medal" => :right, "Competitions" => :right, "Person" => :left }
  end

  def query
    <<-SQL
      SELECT
        CONCAT(FORMAT(100 * competitions_with_medal / competitions, 1), '%') share,
        competitions_with_medal,
        competitions,
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link
      FROM (
        SELECT
          results.person_id,
          COUNT(DISTINCT results.competition_id) competitions,
          COUNT(DISTINCT CASE WHEN results.pos IN (1, 2, 3) AND results.best > 0 AND results.round_type_id IN ('c', 'f') THEN results.competition_id END) competitions_with_medal
        FROM results
        JOIN persons person ON person.wca_id = results.person_id AND person.sub_id = 1 AND person.country_id = 'Poland'
        GROUP BY results.person_id
        HAVING competitions >= 10
      ) AS stats
      JOIN persons person ON person.wca_id = stats.person_id AND person.sub_id = 1
      ORDER BY competitions_with_medal / competitions DESC, competitions DESC, person.name
      LIMIT 100
    SQL
  end
end
