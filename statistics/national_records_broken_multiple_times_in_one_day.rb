require_relative "../core/statistic"
require_relative "../core/events"
require_relative "../core/solve_time"

class NationalRecordsBrokenMultipleTimesInOneDay < Statistic
  RESULTS_LIMIT = 5

  def initialize
    @title = "Days on which a Polish national record was broken more than once"
    @category = :records
    @note = "Following Regulation 9i2, every result of a round counts as achieved on the last local day of that round, so only the best of them is officially recognised as a record. " \
      "Here every result better than or equal to the national record standing before that day is listed. Continental and world records count as national records as well. " \
      "The first day of results in each event is skipped, as there was no record to beat yet. " \
      "Dates marked with \\* come from the competition end date, because the competition has no schedule, so the results may actually span several days."
    @table_header = { "#" => :right, "Date" => :left, "Event" => :left, "Type" => :left, "Previous NR" => :right, "Results" => :left }
  end

  def query
    <<-SQL
      WITH round_last_day AS (
        SELECT
          activity.round_id,
          -- CONVERT_TZ returns NULL when the time zone tables are not loaded, the UTC date is used then.
          MAX(COALESCE(
            DATE(CONVERT_TZ(activity.end_time - INTERVAL 1 SECOND, '+00:00', venue.timezone_id)),
            DATE(activity.end_time - INTERVAL 1 SECOND)
          )) last_day
        FROM schedule_activities activity
        JOIN venue_rooms room ON room.id = activity.venue_room_id
        JOIN competition_venues venue ON venue.id = room.competition_venue_id
        WHERE activity.round_id IS NOT NULL
        GROUP BY activity.round_id
      ),
      polish_results AS (
        SELECT
          result.*,
          COALESCE(round_last_day.last_day, competition.end_date) result_day,
          round_last_day.last_day IS NULL date_from_comp_end
        FROM results result
        JOIN competitions competition ON competition.id = result.competition_id
        LEFT JOIN round_last_day ON round_last_day.round_id = result.round_id
        WHERE result.country_id = 'Poland'
      ),
      results_by_type AS (
        SELECT id, event_id, 'single' record_type, best value, person_id, competition_id, result_day, date_from_comp_end
        FROM polish_results WHERE best > 0
        UNION ALL
        SELECT id, event_id, 'average' record_type, average value, person_id, competition_id, result_day, date_from_comp_end
        FROM polish_results WHERE average > 0
      ),
      day_best AS (
        SELECT event_id, record_type, result_day, MIN(value) best_value
        FROM results_by_type
        GROUP BY event_id, record_type, result_day
      ),
      standing_record AS (
        SELECT
          event_id,
          record_type,
          result_day,
          MIN(best_value) OVER (
            PARTITION BY event_id, record_type ORDER BY result_day
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
          ) nr_before
        FROM day_best
      ),
      record_results AS (
        SELECT
          r.*,
          s.nr_before,
          COUNT(*) OVER (PARTITION BY r.event_id, r.record_type, r.result_day) records_count
        FROM results_by_type r
        JOIN standing_record s USING (event_id, record_type, result_day)
        WHERE r.value <= s.nr_before
      )
      SELECT
        r.event_id,
        r.record_type,
        r.result_day,
        r.date_from_comp_end,
        r.nr_before,
        r.value,
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link,
        CONCAT('[', competition.cell_name, '](https://www.worldcubeassociation.org/competitions/', competition.id, '/results/by_person#', person.wca_id, ')') results_link
      FROM record_results r
      JOIN persons person ON person.wca_id = r.person_id AND person.sub_id = 1
      JOIN competitions competition ON competition.id = r.competition_id
      WHERE r.records_count > 1
      ORDER BY r.result_day, r.event_id, r.record_type DESC, r.value, person.name
    SQL
  end

  def transform(query_results)
    query_results
      .group_by { |result| result.values_at("result_day", "event_id", "record_type") }
      .each_with_index
      .map do |((day, event_id, type), results), index|
        date = results.any? { |result| result["date_from_comp_end"] == 1 } ? "#{day}\\*" : day.to_s
        entries = results.first(RESULTS_LIMIT).map do |result|
          time = SolveTime.new(event_id, type, result["value"]).clock_format
          "#{result['person_link']} **#{time}** @ #{result['results_link']}"
        end
        entries << "+#{results.size - RESULTS_LIMIT} more" if results.size > RESULTS_LIMIT
        [
          index + 1,
          date,
          Events::ALL[event_id] || event_id,
          type.capitalize,
          SolveTime.new(event_id, type, results.first["nr_before"]).clock_format,
          entries.join("<br />"),
        ]
      end
  end
end
