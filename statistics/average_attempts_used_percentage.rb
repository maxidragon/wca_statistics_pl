require_relative "../core/statistic"

class AverageAttemptsUsedPercentage < Statistic
  MIN_COMPETITIONS = 20

  def initialize
    @title = "Highest average percentage of available attempts used"
    @note = "For every competition, the available attempts are the sum of the expected solve counts of all its rounds, no matter which events the competitor signed up for. The used attempts are the ones they actually started (DNFs count, DNSs and attempts lost to a cutoff do not). The percentage is the average of those per-competition ratios, while the attempt counts are totals. Competitions abroad are included. Only Polish competitors with at least #{MIN_COMPETITIONS} competitions are included."
    @table_header = { "%" => :right, "Person" => :left, "Attempted" => :right, "Available" => :right, "Competitions" => :right }
  end

  def query
    <<-SQL
      SELECT
        ROUND(AVG(100.0 * used_attempts / available_attempts), 2) average_percentage,
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link,
        SUM(used_attempts) used_attempts,
        SUM(available_attempts) available_attempts,
        COUNT(*) competitions
      FROM (
        SELECT
          result.person_id,
          result.competition_id,
          SUM(IF(attempt.value != -2, 1, 0)) used_attempts
        FROM results result
        JOIN formats format ON format.id = result.format_id AND format.expected_solve_count > 0
        JOIN result_attempts attempt ON attempt.result_id = result.id
        JOIN persons person ON person.wca_id = result.person_id AND person.sub_id = 1 AND person.country_id = 'Poland'
        GROUP BY result.person_id, result.competition_id
      ) AS per_competition
      JOIN (
        SELECT competition_id, SUM(format.expected_solve_count) available_attempts
        FROM (SELECT DISTINCT competition_id, event_id, round_type_id, format_id FROM results) AS round
        JOIN formats format ON format.id = round.format_id AND format.expected_solve_count > 0
        GROUP BY competition_id
      ) AS competition_attempts ON competition_attempts.competition_id = per_competition.competition_id
      JOIN persons person ON person.wca_id = person_id AND person.sub_id = 1
      GROUP BY person_id, person_link
      HAVING competitions >= #{MIN_COMPETITIONS}
      ORDER BY average_percentage DESC, competitions DESC, person.name
      LIMIT 50
    SQL
  end

  def transform(query_results)
    query_results.map do |result|
      [
        format("%.2f%%", result["average_percentage"]),
        result["person_link"],
        result["used_attempts"],
        result["available_attempts"],
        result["competitions"]
      ]
    end
  end
end
