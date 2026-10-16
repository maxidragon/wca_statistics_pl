require_relative "../../core/statistic"

# Measures how long it took a person to go from their first competition
# as a competitor to the first competition they organized/delegated,
# either in days or in competitions attended in between.
class FirstCompetitionToRoleGap < Statistic
  ROLES = {
    organizer: { table: "competition_organizers", column: "organizer_id", verb: "organizing", participle: "organized" },
    delegate: { table: "competition_delegates", column: "delegate_id", verb: "delegating", participle: "delegated" }
  }.freeze

  def initialize(role:, metric:)
    @role = ROLES.fetch(role)
    @metric = metric
    @table_header =
      case @metric
      when :days
        @title = "Longest time from first competition to #{@role[:verb]} one"
        { "Days" => :right, "Person" => :left, "First competition" => :left, "First #{@role[:participle]}" => :left }
      when :competitions
        @title = "Most competitions attended before #{@role[:verb]} one"
        @note = "Only competitions that started before the first #{@role[:participle]} one are counted."
        { "Competitions" => :right, "Person" => :left, "First competition" => :left, "First #{@role[:participle]}" => :left }
      else
        raise ArgumentError, "Unknown metric: #{metric}"
      end
  end

  def query
    <<-SQL
      WITH role_competitions AS (
        SELECT
          #{@role[:column]} AS user_id,
          competition.id AS competition_id,
          competition.cell_name,
          competition.start_date,
          ROW_NUMBER() OVER (PARTITION BY #{@role[:column]} ORDER BY competition.start_date, competition.id) AS rn
        FROM #{@role[:table]}
        JOIN competitions competition ON competition.id = competition_id
        WHERE show_at_all = 1 AND cancelled_at IS NULL AND start_date < CURDATE()
      ),
      first_role AS (
        SELECT role_competitions.*, person.wca_id, person.name
        FROM role_competitions
        JOIN users user ON user.id = role_competitions.user_id
        JOIN persons person ON person.wca_id = user.wca_id AND person.sub_id = 1 AND person.country_id = 'Poland'
        WHERE rn = 1
      ),
      attended AS (
        SELECT DISTINCT
          first_role.user_id,
          competition.id AS competition_id,
          competition.cell_name,
          competition.start_date
        FROM first_role
        JOIN results ON results.person_id = first_role.wca_id
        JOIN competitions competition ON competition.id = results.competition_id
      ),
      first_attended AS (
        SELECT
          attended.*,
          ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY start_date, competition_id) AS rn
        FROM attended
      ),
      attended_before AS (
        SELECT attended.user_id, COUNT(*) AS competitions_count
        FROM attended
        JOIN first_role ON first_role.user_id = attended.user_id
        WHERE attended.start_date < first_role.start_date
        GROUP BY attended.user_id
      )
      SELECT
        DATEDIFF(first_role.start_date, first_attended.start_date) AS days,
        attended_before.competitions_count,
        CONCAT('[', first_role.name, '](https://www.worldcubeassociation.org/persons/', first_role.wca_id, ')') AS person_link,
        CONCAT('[', first_attended.cell_name, '](https://www.worldcubeassociation.org/competitions/', first_attended.competition_id, ')') AS first_competition_link,
        CONCAT('[', first_role.cell_name, '](https://www.worldcubeassociation.org/competitions/', first_role.competition_id, ')') AS first_role_competition_link
      FROM first_role
      JOIN first_attended ON first_attended.user_id = first_role.user_id AND first_attended.rn = 1
      JOIN attended_before ON attended_before.user_id = first_role.user_id
      ORDER BY #{@metric == :days ? "days DESC, competitions_count DESC" : "competitions_count DESC, days DESC"}
      LIMIT 100
    SQL
  end

  def transform(query_results)
    query_results.map do |result|
      value = @metric == :days ? result["days"] : result["competitions_count"]
      [value, result["person_link"], result["first_competition_link"], result["first_role_competition_link"]]
    end
  end
end
