require_relative "../core/statistic"

class MostCompletedSolvesAtOneCompetition < Statistic
  def initialize
    @title = "Most completed solves at one competition"
    @table_header = { "Person" => :left, "Competition" => :right, "Solves" => :right, "Attempts" => :right }
  end

  def query
    <<-SQL
      SELECT
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link,
        CONCAT('[', competition.cell_name, '](https://www.worldcubeassociation.org/competitions/', competition.id, ')') competition_link,
        SUM(
          IF(value1 > 0, 1, 0) +
          IF(value2 > 0, 1, 0) +
          IF(value3 > 0, 1, 0) +
          IF(value4 > 0, 1, 0) +
          IF(value5 > 0, 1, 0)
        ) completed_count,
        SUM(
          IF(value1 != 0, 1, 0) +
          IF(value2 != 0, 1, 0) +
          IF(value3 != 0, 1, 0) +
          IF(value4 != 0, 1, 0) +
          IF(value5 != 0, 1, 0)
        ) attempts_count
      FROM results result
      JOIN persons person 
        ON person.wca_id = person_id 
        AND sub_id = 1 
        AND person.country_id = 'Poland'
      JOIN competitions competition 
        ON competition.id = competition_id
      GROUP BY person.wca_id, competition.id
      ORDER BY completed_count DESC
      LIMIT 20
    SQL
  end
end
