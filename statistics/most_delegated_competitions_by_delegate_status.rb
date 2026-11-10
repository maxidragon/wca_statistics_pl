require_relative "../core/grouped_statistic"

class MostDelegatedCompetitionsByDelegateStatus < GroupedStatistic
  STATUS_GROUPS = {
    "trainee_delegate" => "Trainee Delegate",
    "junior_delegate" => "Junior Delegate",
    "full_delegate" => "Full Delegate",
  }.freeze

  def initialize
    @title = "Most delegated competitions while being trainee, junior or full delegate"
    @category = :delegating
    @note = "The status is the one the delegate held on the competition's first day. Regional and Senior Delegates count as Full Delegates. The WCA keeps status history only since 2024, so delegates appointed earlier count as Full Delegates for all their competitions, and former delegates without a recorded role are not included."
    @table_header = { "Delegated" => :right, "Person" => :left }
  end

  def query
    <<-SQL
      WITH delegate_roles AS (
        SELECT
          user_role.user_id,
          user_role.start_date,
          user_role.end_date,
          CASE
            WHEN metadata.status IN ('delegate', 'regional_delegate', 'senior_delegate') THEN 'full_delegate'
            ELSE metadata.status
          END status_group
        FROM user_roles user_role
        JOIN roles_metadata_delegate_regions metadata ON metadata.id = user_role.metadata_id
        WHERE user_role.metadata_type = 'RolesMetadataDelegateRegions'
      )
      SELECT
        delegate_role.status_group,
        COUNT(DISTINCT competition.id) delegated_count,
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link
      FROM competition_delegates
      JOIN competitions competition ON competition.id = competition_delegates.competition_id
      JOIN delegate_roles delegate_role
        ON delegate_role.user_id = competition_delegates.delegate_id
        AND delegate_role.start_date <= competition.start_date
        AND (delegate_role.end_date IS NULL OR delegate_role.end_date > competition.start_date)
      JOIN users user ON user.id = competition_delegates.delegate_id
      JOIN persons person ON person.wca_id = user.wca_id AND person.sub_id = 1 AND person.country_id = 'Poland'
      WHERE competition.show_at_all = 1
        AND competition.cancelled_at IS NULL
        AND competition.start_date < CURDATE()
        AND competition.results_posted_at IS NOT NULL
      GROUP BY delegate_role.status_group, person.wca_id, person.name
      ORDER BY delegated_count DESC, person.name
    SQL
  end

  def transform(query_results)
    rows_by_status = query_results.group_by { |row| row["status_group"] }

    STATUS_GROUPS.map do |status_group, header|
      person_rows = rows_by_status
        .fetch(status_group, [])
        .map { |row| [row["delegated_count"], row["person_link"]] }
      [header, person_rows]
    end
  end
end
