require_relative "../core/statistic"

class MostCompetitionsOrganizedInSingleCity < Statistic
  def initialize
    @title = "Most competitions organized in a single city (without organizing elsewhere)"
    @note = "Only Polish organizers and Polish competitions are included. " \
            "Organizers who have organized in more than one city are excluded."
    @table_header = { "Person" => :left, "City" => :left, "Competitions" => :right }
  end

  def query
    <<-SQL
      SELECT
        CASE
          WHEN u.wca_id IS NOT NULL THEN CONCAT('[', u.name, '](https://www.worldcubeassociation.org/persons/', u.wca_id, ')')
          ELSE u.name
        END AS person_link,
        MAX(c.city_name) AS city,
        COUNT(DISTINCT co.competition_id) AS organized_count
      FROM competition_organizers co
      JOIN competitions c ON c.id = co.competition_id
      JOIN users u ON u.id = co.organizer_id AND u.country_iso2 = 'PL'
      WHERE c.country_id = 'Poland'
        AND c.show_at_all = 1
        AND c.cancelled_at IS NULL
        AND c.start_date < CURDATE()
      GROUP BY co.organizer_id
      HAVING COUNT(DISTINCT c.city_name) = 1
      ORDER BY organized_count DESC
      LIMIT 100
    SQL
  end
end
