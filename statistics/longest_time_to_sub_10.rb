require_relative "../core/statistic"

class LongestTimeToSub10 < Statistic
  def initialize
    @title = "Longest time to achieve sub 10 3x3x3 average"
    @table_header = { "Person" => :left, "Years" => :right }
  end

  def query
    <<-SQL
      WITH polish_sub10 AS (
        SELECT ra.person_id
        FROM ranks_average ra
        JOIN persons p ON p.wca_id = ra.person_id AND p.sub_id = 1 AND p.country_id = 'Poland'
        WHERE ra.event_id = '333' AND ra.best < 1000
      )
      SELECT
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link,
        (DATEDIFF(first_sub_10_competition.start_date, first_competition.start_date) / 365.25) years
      FROM polish_sub10
      JOIN persons person ON person.wca_id = polish_sub10.person_id AND person.sub_id = 1
      JOIN (
        SELECT r.person_id, MIN(c.start_date) AS start_date
        FROM results r
        JOIN competitions c ON c.id = r.competition_id
        JOIN polish_sub10 ps ON ps.person_id = r.person_id
        GROUP BY r.person_id
      ) AS first_competition ON first_competition.person_id = polish_sub10.person_id
      JOIN (
        SELECT r.person_id, MIN(c.start_date) AS start_date
        FROM results r
        JOIN competitions c ON c.id = r.competition_id
        JOIN polish_sub10 ps ON ps.person_id = r.person_id
        WHERE r.event_id = '333' AND r.average > 0 AND r.average < 1000
        GROUP BY r.person_id
      ) AS first_sub_10_competition ON first_sub_10_competition.person_id = polish_sub10.person_id
      ORDER BY years DESC
      LIMIT 100
    SQL
  end

  def transform(query_results)
    query_results.map do |result|
      [result["person_link"], "%0.2f" % result["years"]]
    end
  end
end
