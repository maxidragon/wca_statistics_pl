require_relative "../core/statistic"

class DelegatedACompetitionInMostCountries < Statistic
  def initialize
    @title = "Delegated a competition in most countries"
    @note = "This statistic shows the Polish delegates who have delegated a competition in most countries. Multi-location FMC competitions are excluded."
    @table_header = { "Name" => :left, "Countries" => :right }
  end

  def query
    <<-SQL
      SELECT 
          CASE 
              WHEN d.wca_id IS NOT NULL THEN CONCAT('[', d.name, '](https://www.worldcubeassociation.org/persons/', d.wca_id, ')')
              ELSE d.name 
          END as delegate_name,
          COUNT(DISTINCT c.country_id) AS num_countries
      FROM 
          competition_delegates cd
      JOIN 
          competitions c ON cd.competition_id = c.id
      JOIN 
          users d ON cd.delegate_id = d.id AND d.country_iso2 = 'PL'
      WHERE
          c.country_id NOT IN ('XA', 'XE', 'XF', 'XM', 'XN', 'XO', 'XS', 'XW')
      GROUP BY 
          d.id, d.name, d.wca_id
      ORDER BY 
          num_countries DESC, d.name ASC;
    SQL
  end
end
