require_relative "../core/statistic"

class MedalsCompetitionsRatio < Statistic
  def initialize
    @title = "Medals to competitions ratio"
    @note = "Only Polish competitors included"
    @table_header = { "Person" => :left, "Medals" => :right, "Competitions" => :right, "Ratio" => :right }
  end

  def query
    <<-SQL
      SELECT
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link,
        stats.medals,
        stats.competitions,
        FORMAT(stats.medals / stats.competitions, 2) AS ratio
      FROM (
        SELECT
          r.person_id,
          SUM(IF(r.pos IN (1,2,3) AND r.best > 0 AND r.round_type_id IN ('c', 'f'), 1, 0)) AS medals,
          COUNT(DISTINCT r.competition_id) AS competitions
        FROM results r
        JOIN persons person ON person.wca_id = r.person_id AND person.sub_id = 1 AND person.country_id = 'Poland'
        GROUP BY r.person_id
      ) AS stats
      JOIN persons person ON person.wca_id = stats.person_id AND person.sub_id = 1
      WHERE stats.competitions > 0
        AND (stats.medals / stats.competitions) > 2
      ORDER BY (stats.medals / stats.competitions) DESC, stats.medals DESC, stats.competitions ASC, person.name
    SQL
  end
end
