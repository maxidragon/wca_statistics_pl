require_relative "../core/grouped_statistic"

class MostDelegatedAndOrganizedCompetitionsByYear < GroupedStatistic
  def initialize
    @title = "Most delegated and organized competitions each year"
    @note = "This statistic shows how many of the competitions delegated by each Polish delegate in a given year were also organized by them."
    @table_header = {
      "Delegated & organized" => :right,
      "Delegated" => :right,
      "Share" => :right,
      "Person" => :left
    }
  end

  def query
    <<-SQL
      SELECT
        year,
        delegated_and_organized_count,
        delegated_count,
        CONCAT(FORMAT(100 * delegated_and_organized_count / delegated_count, 1), '%') AS share,
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link
      FROM (
        SELECT
          delegate_id,
          YEAR(competition.start_date) year,
          COUNT(DISTINCT competition_delegates.competition_id) delegated_count,
          COUNT(DISTINCT CASE WHEN organizer_id IS NOT NULL THEN competition_delegates.competition_id END) delegated_and_organized_count
        FROM competition_delegates
        JOIN competitions competition ON competition.id = competition_delegates.competition_id
        LEFT JOIN competition_organizers
          ON competition_organizers.competition_id = competition_delegates.competition_id
          AND competition_organizers.organizer_id = competition_delegates.delegate_id
        WHERE show_at_all = 1 AND cancelled_at IS NULL AND start_date < CURDATE() AND results_posted_at IS NOT NULL
        GROUP BY delegate_id, year
      ) AS counts_by_user
      JOIN users user ON user.id = delegate_id
      JOIN persons person ON person.wca_id = user.wca_id AND person.sub_id = 1 AND person.country_id = 'Poland'
      ORDER BY year DESC, delegated_and_organized_count / delegated_count DESC, delegated_and_organized_count DESC
    SQL
  end

  def transform(query_results)
    query_results
      .group_by { |row| row["year"] }
      .map do |year, rows|
        person_rows = rows.map do |row|
          [row["delegated_and_organized_count"], row["delegated_count"], row["share"], row["person_link"]]
        end
        [year, person_rows]
      end
  end
end
