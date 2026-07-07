require_relative "../core/grouped_statistic"
require_relative "../core/events"

class MostSuccessfulSolvesPercentageByEvent < GroupedStatistic
  MIN_ATTEMPTS = 10

  def initialize
    @title = "Most % of successful solves in each event"
    @note = "Counts individual attempt values. A successful attempt has value > 0 (not DNF). DNS attempts are excluded. Minimum #{MIN_ATTEMPTS} attempts required."
    @table_header = { "%" => :right, "Successful" => :right, "Total" => :right, "Person" => :left }
  end

  def query
    <<-SQL
      SELECT
        r.event_id,
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link,
        SUM(IF(ra.value > 0, 1, 0)) AS successful,
        COUNT(*) AS total
      FROM results r
      JOIN result_attempts ra ON ra.result_id = r.id
      JOIN persons person ON person.wca_id = r.person_id AND person.sub_id = 1 AND person.country_id = 'Poland'
      WHERE ra.value != 0 AND ra.value != -2
      GROUP BY r.event_id, r.person_id, person_link
    SQL
  end

  def transform(query_results)
    Events::ALL.map do |event_id, event_name|
      results = query_results
        .select { |r| r["event_id"] == event_id && r["total"] >= MIN_ATTEMPTS }
        .map { |r| [r["successful"].to_f / r["total"] * 100, r["successful"], r["total"], r["person_link"]] }
        .sort_by { |pct, successful, _, _| [-pct, -successful] }
        .first(20)
        .map { |pct, successful, total, person_link| ["#{"%.2f" % pct}%", successful, total, person_link] }

      [event_name, results]
    end
  end
end
