require_relative "../core/statistic"

class MostCompetitionRoundsPercentage < Statistic
  MIN_ROUNDS = 10

  def initialize
    @title = "Most % of rounds competed in at one competition"
    @note = "Shows the highest percentage of a competition's rounds that a Polish competitor participated in. Only competitions with more than 1 event and more than #{MIN_ROUNDS} rounds are included."
    @table_header = { "%" => :right, "Person" => :left, "Competition" => :left, "Rounds competed" => :right, "Total rounds" => :right }
  end

  def query
    <<-SQL
      SELECT
        ROUND(person_rounds / total_rounds * 100, 1) AS percentage,
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link,
        CONCAT('[', competition.cell_name, '](https://www.worldcubeassociation.org/competitions/', competition.id, ')') competition_link,
        person_rounds,
        total_rounds
      FROM (
        SELECT competition_id, person_id, COUNT(*) person_rounds
        FROM (
          SELECT DISTINCT competition_id, person_id, event_id, round_type_id
          FROM results
        ) AS distinct_person_rounds
        GROUP BY competition_id, person_id
      ) AS person_round_counts
      JOIN (
        SELECT competition_id, COUNT(*) total_rounds, COUNT(DISTINCT event_id) event_count
        FROM (
          SELECT DISTINCT competition_id, event_id, round_type_id
          FROM results
        ) AS distinct_rounds
        GROUP BY competition_id
        HAVING total_rounds > #{MIN_ROUNDS} AND event_count > 1
      ) AS competition_round_counts ON competition_round_counts.competition_id = person_round_counts.competition_id
      JOIN persons person ON person.wca_id = person_id AND person.sub_id = 1 AND person.country_id = 'Poland'
      JOIN competitions competition ON competition.id = person_round_counts.competition_id
      ORDER BY percentage DESC, total_rounds DESC
      LIMIT 50
    SQL
  end

  def transform(query_results)
    query_results.map do |result|
      [format("%.1f%%", result["percentage"]), result["person_link"], result["competition_link"], result["person_rounds"], result["total_rounds"]]
    end
  end
end
