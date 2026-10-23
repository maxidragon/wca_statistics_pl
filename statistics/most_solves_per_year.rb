require_relative "../core/grouped_statistic"

class MostSolvesPerYear < GroupedStatistic
  def initialize
    @title = "Most solves per year"
    @category = :results
    @note = "Only the 25 competitors with the most solves are listed for each year."
    @table_header = { "Solves" => :right, "Attempts" => :right, "Person" => :left }
  end

  def query
    <<-SQL
      SELECT
        CONCAT('[', p.name, '](https://www.worldcubeassociation.org/persons/', p.wca_id, ')') AS person_link,
        YEAR(c.start_date) AS year,
        SUM(CASE WHEN ra.value > 0 THEN 1 ELSE 0 END) AS completed_count,
        SUM(CASE WHEN ra.value > 0 OR ra.value = -1 THEN 1 ELSE 0 END) AS attempts_count
      FROM results r
      JOIN persons p ON p.wca_id = r.person_id AND p.sub_id = 1 AND p.country_id = 'Poland'
      JOIN result_attempts ra ON ra.result_id = r.id
      JOIN competitions c ON c.id = r.competition_id
      GROUP BY p.wca_id, p.name, year
    SQL
  end

  def transform(query_results)
    query_results
      .group_by { |result| result["year"] }
      .sort_by { |year, results| -year }
      .map do |year, results|
        person_rows = results
          .sort_by { |result| [-result["completed_count"], result["attempts_count"], result["person_link"]] }
          .first(25)
          .map { |result| ["**#{result['completed_count']}**", result["attempts_count"], result["person_link"]] }
        [year, person_rows]
      end
  end
end
