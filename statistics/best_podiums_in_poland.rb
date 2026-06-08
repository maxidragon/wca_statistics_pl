require_relative "../core/grouped_statistic"
require_relative "../core/events"
require_relative "../core/solve_time"

class BestPodiumsInPoland < GroupedStatistic
  def initialize
    @title = "Best podiums at Polish competitions"
    @note = "Podium places with sum of best or average times depending on format."
    @table_header = { "Competition" => :left, "Podium" => :left, "Total" => :right }
  end

  def query
    <<-SQL
      WITH fm_round_formats AS (
        SELECT
          r.competition_id,
          r.round_type_id,
          CASE MAX(ra.attempt_number)
            WHEN 3 THEN 'm'
            WHEN 2 THEN '2'
            ELSE '1'
          END AS actual_format_id
        FROM results r
        JOIN result_attempts ra ON ra.result_id = r.id
        WHERE r.event_id = '333fm'
          AND ra.value != 0
        GROUP BY r.competition_id, r.round_type_id
      )
      SELECT DISTINCT
        results.event_id,
        results.competition_id,
        competition.cell_name competition_name,
        results.person_id,
        results.person_name,
        results.pos,
        results.best,
        results.average,
        COALESCE(fm_format.sort_by, pref_format.sort_by) AS sort_by,
        COALESCE(frf.actual_format_id, preferred_format.format_id) AS actual_format_id
      FROM results
      JOIN competitions competition ON competition.id = results.competition_id AND competition.country_id = 'Poland'
      JOIN preferred_formats preferred_format ON preferred_format.event_id = results.event_id AND preferred_format.ranking = 1
      JOIN formats pref_format ON pref_format.id = preferred_format.format_id
      LEFT JOIN fm_round_formats frf ON frf.competition_id = results.competition_id
        AND frf.round_type_id = results.round_type_id
        AND results.event_id = '333fm'
      LEFT JOIN formats fm_format ON fm_format.id = frf.actual_format_id
      WHERE results.pos IN (1, 2, 3)
        AND results.round_type_id IN ('c', 'f')
        AND NOT (results.round_type_id = 'c' AND EXISTS (
          SELECT 1 FROM results r2
          WHERE r2.competition_id = results.competition_id
            AND r2.event_id = results.event_id
            AND r2.round_type_id = 'f'
        ))
        AND results.best > 0
        AND (COALESCE(fm_format.sort_by, pref_format.sort_by) = 'single' OR results.average > 0)
      ORDER BY results.event_id, results.best
    SQL
  end

  def transform(query_results)
    podiums_by_event = Hash.new { |h, k| h[k] = {} }

    query_results.each do |row|
      event_id = row["event_id"]
      comp_id = row["competition_id"]

      key = event_id == '333fm' ? "#{comp_id}|#{row['actual_format_id']}" : comp_id

      podiums_by_event[event_id][key] ||= {
        name: row["competition_name"],
        rows: [],
        actual_format_id: row["actual_format_id"]
      }

      podiums_by_event[event_id][key][:rows] << row
    end

    result = []
    Events::ALL.each do |event_id, event_name|
      if event_id == '333fm'
        [['m', 'Mean of 3'], ['2', 'Best of 2'], ['1', 'Best of 1']].each do |format_id, format_label|
          podiums = podiums_by_event[event_id]
            .select { |_, data| data[:actual_format_id] == format_id }
            .values
            .map { |podium_data| build_podium_row(event_id, podium_data) }
            .compact
            .sort_by { |_, _, _, total_raw| total_raw }
            .first(10)
            .map { |comp_link, people, total_display, _| [comp_link, people, total_display] }
          result << ["#{event_name} (#{format_label})", podiums] unless podiums.empty?
        end
      else
        podiums = podiums_by_event[event_id].values
          .map { |podium_data| build_podium_row(event_id, podium_data) }
          .compact
          .sort_by { |_, _, _, total_raw| total_raw }
          .first(10)
          .map { |comp_link, people, total_display, _| [comp_link, people, total_display] }
        result << [event_name, podiums]
      end
    end
    result
  end

  private

  def build_podium_row(event_id, podium_data)
    rows = podium_data[:rows]
    use_average = rows.first["sort_by"] == "average"
    sorted_rows = rows.sort_by { |r| [r["pos"], use_average ? r["average"].to_i : r["best"].to_i] }
    return nil if sorted_rows.size < 3

    comp_link = "[#{podium_data[:name]}](https://www.worldcubeassociation.org/competitions/#{rows.first["competition_id"]})"

    people = sorted_rows.first(3)
      .map do |r|
        time_raw = use_average ? r["average"].to_i : r["best"].to_i
        time = SolveTime.new(event_id, use_average ? :average : :single, time_raw).clock_format
        "[#{r["person_name"]}](https://www.worldcubeassociation.org/persons/#{r["person_id"]}) (#{time})"
      end
      .join(", ")

    if %w[333mbf 333mbo].include?(event_id)
      total_points = sorted_rows.first(3).sum { |r| SolveTime.new(event_id, :single, r["best"].to_i).points }
      [comp_link, people, total_points.to_s, -total_points]
    else
      total_raw = sorted_rows.first(3).sum { |r| use_average ? r["average"].to_i : r["best"].to_i }
      total_display = SolveTime.new(event_id, use_average ? :average : :single, total_raw).clock_format
      [comp_link, people, total_display, total_raw]
    end
  end
end
