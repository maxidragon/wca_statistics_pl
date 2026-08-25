require_relative "../core/grouped_statistic"

class DelegatedToAttendedCompetitionsRatioByYear < GroupedStatistic
  def initialize
    @title = "Delegated to attended competition ratio each year (Poland)"
    @table_header = {
      "Delegated" => :right,
      "Attended" => :right,
      "Ratio" => :right,
      "Person" => :left,
      "List on WCA" => :center
    }
  end

  def query
    <<-SQL
      SELECT
        delegated.year,
        delegated_count,
        attended_count,
        FORMAT(delegated_count / attended_count, 2) AS ratio,
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') AS person_link,
        CONCAT('[List](https://www.worldcubeassociation.org/competitions?year=all+years&state=past&delegate=', users.id, ')') AS list_link
      FROM (
        SELECT
          delegate_id,
          YEAR(start_date) AS year,
          COUNT(DISTINCT competition_id) AS delegated_count
        FROM competition_delegates
        JOIN competitions ON competitions.id = competition_id
        WHERE show_at_all = 1
          AND cancelled_at IS NULL
          AND start_date < CURDATE()
          AND results_posted_at IS NOT NULL
        GROUP BY delegate_id, year
      ) AS delegated
      JOIN users ON users.id = delegated.delegate_id
      JOIN (
        SELECT
          person_id,
          YEAR(competition.start_date) AS year,
          COUNT(DISTINCT results.competition_id) AS attended_count
        FROM results
        JOIN competitions competition ON competition.id = results.competition_id
        WHERE results.country_id = "Poland"
        GROUP BY person_id, year
      ) AS attended ON attended.person_id = users.wca_id AND attended.year = delegated.year
      JOIN persons person ON person.wca_id = users.wca_id AND person.sub_id = 1 AND person.country_id = 'Poland'
      ORDER BY delegated.year DESC, delegated_count / attended_count DESC, delegated_count DESC
    SQL
  end

  def transform(query_results)
    query_results
      .group_by { |row| row["year"] }
      .map do |year, rows|
        person_rows = rows.map do |row|
          [row["delegated_count"], row["attended_count"], row["ratio"], row["person_link"], row["list_link"]]
        end
        [year, person_rows]
      end
  end
end
