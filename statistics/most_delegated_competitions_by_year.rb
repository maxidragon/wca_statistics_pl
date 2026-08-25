require_relative "../core/grouped_statistic"

class MostDelegatedCompetitionsByYear < GroupedStatistic
  def initialize
    @title = "Most delegated competitions each year"
    @table_header = { "Delegated" => :right, "Person" => :left, "List on WCA" => :center }
  end

  def query
    <<-SQL
      SELECT
        year,
        delegated_count,
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link,
        CONCAT('[List](https://www.worldcubeassociation.org/competitions?year=all+years&state=past&delegate=', user.id, ')') list_link
      FROM (
        SELECT
          YEAR(competition.start_date) year,
          COUNT(DISTINCT competition_id) delegated_count,
          delegate_id
        FROM competition_delegates
        JOIN competitions competition ON competition.id = competition_id
        WHERE show_at_all = 1 AND cancelled_at IS NULL AND start_date < CURDATE() AND results_posted_at IS NOT NULL
        GROUP BY delegate_id, year
      ) AS delegated_count_by_user
      JOIN users user ON user.id = delegate_id
      JOIN persons person ON person.wca_id = user.wca_id AND person.sub_id = 1 AND person.country_id = 'Poland'
      ORDER BY year DESC, delegated_count DESC
    SQL
  end

  def transform(query_results)
    query_results
      .group_by { |row| row["year"] }
      .map do |year, rows|
        person_rows = rows.map { |row| [row["delegated_count"], row["person_link"], row["list_link"]] }
        [year, person_rows]
      end
  end
end
