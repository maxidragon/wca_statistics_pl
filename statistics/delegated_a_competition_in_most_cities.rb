require_relative "../core/statistic"

class DelegatedACompetitionInMostCities < Statistic
  def initialize
    @title = "Delegated a competition in most cities"
    @category = :delegating
    @note = "This statistic shows the Polish delegates who have delegated a competition in most cities. " \
            "Cities with the same name in different countries are counted separately. " \
            "Multi-location FMC competitions are excluded."
    @table_header = { "Name" => :left, "Cities" => :right, "Countries" => :right }
  end

  def query
    <<-SQL
      SELECT
          CASE
              WHEN d.wca_id IS NOT NULL THEN CONCAT('[', d.name, '](https://www.worldcubeassociation.org/persons/', d.wca_id, ')')
              ELSE d.name
          END AS delegate_name,
          COUNT(DISTINCT c.country_id, c.city_name) AS num_cities,
          COUNT(DISTINCT c.country_id) AS num_countries
      FROM
          competition_delegates cd
      JOIN
          competitions c ON cd.competition_id = c.id
      JOIN
          users d ON cd.delegate_id = d.id AND d.country_iso2 = 'PL'
      WHERE
          c.country_id NOT IN ('XA', 'XE', 'XF', 'XM', 'XN', 'XO', 'XS', 'XW')
          AND c.show_at_all = 1
          AND c.cancelled_at IS NULL
          AND c.start_date < CURDATE()
      GROUP BY
          d.id, d.name, d.wca_id
      ORDER BY
          num_cities DESC, num_countries DESC, d.name ASC
      LIMIT 100;
    SQL
  end
end
