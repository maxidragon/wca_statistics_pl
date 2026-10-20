require_relative "../../core/grouped_statistic"

# For each Polish city, lists the Polish people who organized/delegated
# the most competitions there.
class RoleCompetitionsInCity < GroupedStatistic
  ROLES = {
    organizer: { table: "competition_organizers", column: "organizer_id", participle: "organized", noun: "organizers", category: :organizing },
    delegate: { table: "competition_delegates", column: "delegate_id", participle: "delegated", noun: "delegates", category: :delegating }
  }.freeze

  def initialize(role:)
    @role = ROLES.fetch(role)
    @title = "Most #{@role[:participle]} competitions in a city"
    @category = @role[:category]
    @note = "Only Polish #{@role[:noun]} and Polish competitions are included."
    @table_header = { "Person" => :left, "Competitions" => :right }
  end

  def query
    <<-SQL
      SELECT
        u.id AS user_id,
        CASE
          WHEN u.wca_id IS NOT NULL THEN CONCAT('[', u.name, '](https://www.worldcubeassociation.org/persons/', u.wca_id, ')')
          ELSE u.name
        END AS person_link,
        c.id AS competition_id,
        c.city_name
      FROM #{@role[:table]} cr
      JOIN competitions c ON c.id = cr.competition_id
      JOIN users u ON u.id = cr.#{@role[:column]} AND u.country_iso2 = 'PL'
      WHERE c.country_id = 'Poland'
        AND c.show_at_all = 1
        AND c.cancelled_at IS NULL
        AND c.start_date < CURDATE()
      GROUP BY u.id, c.id
    SQL
  end

  def transform(results)
    comp_ids_per_city = Hash.new { |h, k| h[k] = Set.new }
    person_count_per_city = Hash.new { |h, k| h[k] = Hash.new(0) }
    person_links = {}

    results.each do |row|
      city = row["city_name"]
      user_id = row["user_id"]
      person_links[user_id] ||= row["person_link"]
      comp_ids_per_city[city] << row["competition_id"]
      person_count_per_city[city][user_id] += 1
    end

    comp_ids_per_city
      .sort_by { |_, ids| -ids.size }
      .map do |city, ids|
        person_rows = person_count_per_city[city]
          .sort_by { |_, count| -count }
          .first(30)
          .map { |user_id, count| [person_links[user_id], count] }

        header = "#{city}\n_Total competitions: #{ids.size}_"
        [header, person_rows]
      end
  end
end
