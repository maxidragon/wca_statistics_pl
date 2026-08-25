require_relative "../core/grouped_statistic"

class MostAttendedCompetitionsByYear < GroupedStatistic
  def initialize
    @title = "Most competitions each year"
    @note = "Only the 25 competitors with the most competitions are listed for each year."
    @table_header = { "Competitions" => :right, "Person" => :left }
  end

  def query
    <<-SQL
      SELECT
        YEAR(competition.start_date) AS year,
        COUNT(DISTINCT results.competition_id) AS competitions_count,
        CONCAT('[', person_name, '](https://www.worldcubeassociation.org/persons/', person_id, ')') person_link
      FROM results
      JOIN competitions competition ON competition.id = results.competition_id
      WHERE results.country_id = "Poland"
      GROUP BY year, person_id, person_name
      ORDER BY year DESC, competitions_count DESC
    SQL
  end

  def transform(query_results)
    query_results
      .group_by { |row| row["year"] }
      .map do |year, rows|
        person_rows = rows.first(25).map { |row| [row["competitions_count"], row["person_link"]] }
        [year, person_rows]
      end
  end
end
