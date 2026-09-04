require_relative "../core/statistic"

class MostCompletedSolvesAtOneCompetition < Statistic
  def initialize
    @title = "Most completed solves at one competition"
    @table_header = { "Person" => :left, "Competition" => :right, "Solves" => :right, "Attempts" => :right }
  end

  def query
    <<-SQL
      WITH person_competition_solves AS (
        SELECT
          r.person_id,
          r.competition_id,
          SUM(ra.value > 0) completed_count,
          SUM(ra.value != 0) attempts_count
        FROM results r
        JOIN result_attempts ra ON ra.result_id = r.id
        WHERE r.country_id = 'Poland'
        GROUP BY r.person_id, r.competition_id
        ORDER BY completed_count DESC, attempts_count ASC, r.person_id, r.competition_id
        LIMIT 20
      )
      SELECT
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link,
        CONCAT('[', competition.cell_name, '](https://www.worldcubeassociation.org/competitions/', competition.id, ')') competition_link,
        pcs.completed_count,
        pcs.attempts_count
      FROM person_competition_solves pcs
      JOIN persons person
        ON person.wca_id = pcs.person_id
        AND person.sub_id = 1
      JOIN competitions competition
        ON competition.id = pcs.competition_id
      ORDER BY pcs.completed_count DESC, pcs.attempts_count ASC, pcs.person_id, pcs.competition_id
    SQL
  end
end
