require_relative "../core/statistic"

class DelegatedACompetitionInMostCities < Statistic
  def initialize
    @title = "Delegated a competition in most Polish cities"
    @category = :delegating
    @note = "This statistic shows the Polish delegates who have delegated a competition in most cities in Poland."
    @table_header = { "Name" => :left, "Cities" => :right }
  end

  def query
    <<-SQL
      SELECT
          CASE
              WHEN d.wca_id IS NOT NULL THEN CONCAT('[', d.name, '](https://www.worldcubeassociation.org/persons/', d.wca_id, ')')
              ELSE d.name
          END AS delegate_name,
          COUNT(DISTINCT c.city_name) AS num_cities
      FROM
          competition_delegates cd
      JOIN
          competitions c ON cd.competition_id = c.id
      JOIN
          users d ON cd.delegate_id = d.id AND d.country_iso2 = 'PL'
      WHERE
          c.country_id = 'Poland'
          AND c.show_at_all = 1
          AND c.cancelled_at IS NULL
          AND c.start_date < CURDATE()
      GROUP BY
          d.id, d.name, d.wca_id
      ORDER BY
          num_cities DESC, d.name ASC
      LIMIT 100;
    SQL
  end
end
