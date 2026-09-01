require_relative "../core/statistic"

class AverageNewPeopleMetPerCompetition < Statistic
  MIN_COMPETITIONS = 20

  def initialize
    @title = "Highest average number of new people met per competition"
    @note = "Divides all unique co-competitors met across a competitor's career by their number of competitions. A co-competitor is someone of any nationality who recorded a result at the same competition, and each person counts only once. Minimum #{MIN_COMPETITIONS} competitions required."
    @table_header = { "Avg. new people" => :right, "Unique people" => :right, "Competitions" => :right, "Person" => :left }
  end

  def query
    <<-SQL
      SELECT
        COUNT(DISTINCT co_competitor.person_id) / COUNT(DISTINCT attendance.competition_id) average_new_people,
        COUNT(DISTINCT co_competitor.person_id) unique_people,
        COUNT(DISTINCT attendance.competition_id) competitions,
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link
      FROM (
        SELECT DISTINCT r.person_id, r.competition_id
        FROM results r
        JOIN persons p ON p.wca_id = r.person_id AND p.sub_id = 1 AND p.country_id = 'Poland'
      ) AS attendance
      LEFT JOIN results co_competitor
        ON co_competitor.competition_id = attendance.competition_id
        AND co_competitor.person_id != attendance.person_id
      JOIN persons person ON person.wca_id = attendance.person_id AND person.sub_id = 1
      GROUP BY attendance.person_id, person_link
      HAVING competitions >= #{MIN_COMPETITIONS}
      ORDER BY average_new_people DESC, unique_people DESC, person_link
      LIMIT 100
    SQL
  end

  def transform(query_results)
    query_results.map do |result|
      [
        format("%.2f", result["average_new_people"]),
        result["unique_people"],
        result["competitions"],
        result["person_link"]
      ]
    end
  end
end
