require_relative "../core/statistic"

class MostDelegatedCompetitions < Statistic
  def initialize
    @title = "Most delegated competitions"
    @category = :delegating
    @note = "Trainee, Junior and Full count competitions by the status the delegate held on the competition's first day; Regional and Senior Delegates count as Full. The WCA keeps status history only since 2024, so delegates appointed earlier count as Full for all their competitions, and competitions delegated without a recorded role count as Unknown."
    @table_header = {
      "Delegated" => :right,
      "Person" => :left,
      "Trainee" => :right,
      "Junior" => :right,
      "Full" => :right,
      "Unknown" => :right,
      "List on WCA" => :center
    }
  end

  def query
    <<-SQL
      WITH delegate_roles AS (
        SELECT
          user_role.user_id,
          user_role.start_date,
          user_role.end_date,
          CASE metadata.status
            WHEN 'trainee_delegate' THEN 1
            WHEN 'junior_delegate' THEN 2
            ELSE 3
          END status_rank
        FROM user_roles user_role
        JOIN roles_metadata_delegate_regions metadata ON metadata.id = user_role.metadata_id
        WHERE user_role.metadata_type = 'RolesMetadataDelegateRegions'
      ),
      delegated_competitions AS (
        SELECT
          competition_delegates.delegate_id,
          competition.id competition_id,
          MAX(delegate_role.status_rank) status_rank
        FROM competition_delegates
        JOIN competitions competition ON competition.id = competition_delegates.competition_id
        LEFT JOIN delegate_roles delegate_role
          ON delegate_role.user_id = competition_delegates.delegate_id
          AND delegate_role.start_date <= competition.start_date
          AND (delegate_role.end_date IS NULL OR delegate_role.end_date > competition.start_date)
        WHERE competition.show_at_all = 1
          AND competition.cancelled_at IS NULL
          AND competition.start_date < CURDATE()
          AND competition.results_posted_at IS NOT NULL
        GROUP BY competition_delegates.delegate_id, competition.id
      )
      SELECT
        delegated_count,
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link,
        trainee_count,
        junior_count,
        full_count,
        unknown_count,
        CONCAT('[List](https://www.worldcubeassociation.org/competitions?year=all+years&state=past&delegate=', user.id, ')') list_link
      FROM (
        SELECT
          delegate_id,
          COUNT(*) delegated_count,
          COUNT(CASE WHEN status_rank = 1 THEN 1 END) trainee_count,
          COUNT(CASE WHEN status_rank = 2 THEN 1 END) junior_count,
          COUNT(CASE WHEN status_rank = 3 THEN 1 END) full_count,
          COUNT(CASE WHEN status_rank IS NULL THEN 1 END) unknown_count
        FROM delegated_competitions
        GROUP BY delegate_id
      ) AS delegated_count_by_user
      JOIN users user ON user.id = delegate_id
      JOIN persons person ON person.wca_id = user.wca_id AND person.sub_id = 1 AND person.country_id = 'Poland'
      ORDER BY delegated_count DESC
    SQL
  end
end
