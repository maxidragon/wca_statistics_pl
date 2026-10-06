require_relative "../core/statistic"

class MostChampionshipsAttended < Statistic
  TOP_POSITIONS = 20

  def initialize
    @title = "Most championships attended"
    @note = "World, European and Polish Championships are counted. Only results achieved while representing Poland are included. Up to the top #{TOP_POSITIONS} positions are listed, so ties may add more rows."
    @table_header = { "Position" => :right, "Person" => :left, "Total" => :right, "World" => :right, "European" => :right, "Polish" => :right }
  end

  def query
    <<-SQL
      WITH attended AS (
        SELECT DISTINCT result.person_id, championship.competition_id, championship.championship_type
        FROM results result
        JOIN championships championship ON championship.competition_id = result.competition_id
        WHERE result.country_id = 'Poland'
          AND championship.championship_type IN ('world', '_Europe', 'PL')
      ),
      ranked AS (
        SELECT
          person_id,
          COUNT(*) AS total,
          SUM(championship_type = 'world') AS world,
          SUM(championship_type = '_Europe') AS european,
          SUM(championship_type = 'PL') AS polish,
          RANK() OVER (ORDER BY COUNT(*) DESC) AS position
        FROM attended
        GROUP BY person_id
      )
      SELECT
        ranked.position,
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') AS person_link,
        ranked.total,
        ranked.world,
        ranked.european,
        ranked.polish
      FROM ranked
      JOIN persons person ON person.wca_id = ranked.person_id AND person.sub_id = 1
      WHERE ranked.position <= #{TOP_POSITIONS}
      ORDER BY ranked.position, ranked.world DESC, ranked.european DESC, person.name
    SQL
  end
end
