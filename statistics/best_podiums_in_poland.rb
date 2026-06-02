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
      SELECT DISTINCT
        results.event_id,
        results.competition_id,
        competition.cell_name competition_name,
        results.person_id,
        results.person_name,
        results.pos,
        results.best,
        results.average,
        format.sort_by
      FROM results
      JOIN competitions competition ON competition.id = results.competition_id AND competition.country_id = 'Poland'
      JOIN preferred_formats preferred_format ON preferred_format.event_id = results.event_id AND preferred_format.ranking = 1
      JOIN formats format ON format.id = preferred_format.format_id
      WHERE results.pos IN (1, 2, 3)
        AND results.round_type_id IN ('c', 'f')
        AND NOT (results.round_type_id = 'c' AND EXISTS (
          SELECT 1 FROM results r2
          WHERE r2.competition_id = results.competition_id
            AND r2.event_id = results.event_id
            AND r2.round_type_id = 'f'
        ))
        AND results.best > 0
        AND (format.sort_by = 'single' OR results.average > 0)
      ORDER BY results.event_id, results.best
    SQL
  end

  def transform(query_results)
    podiums_by_event = Hash.new { |h, k| h[k] = {} }
  
    query_results.each do |row|
      event_id = row["event_id"]
      comp_id = row["competition_id"]
  
      podiums_by_event[event_id][comp_id] ||= {
        name: row["competition_name"],
        rows: []
      }
  
      podiums_by_event[event_id][comp_id][:rows] << row
    end
  
    Events::ALL.map do |event_id, event_name|
      podiums = podiums_by_event[event_id].values
        .map do |podium_data|
          rows = podium_data[:rows]
          use_average = rows.first["sort_by"] == "average"
          sorted_rows = rows.sort_by { |r| [r["pos"], use_average ? r["average"].to_i : r["best"].to_i] }
          next if sorted_rows.size < 3

          comp_link = "[#{podium_data[:name]}](https://www.worldcubeassociation.org/competitions/#{rows.first["competition_id"]})"

          people = sorted_rows
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
        .compact
        .sort_by { |_, _, _, total_raw| total_raw }
        .first(10)
        .map { |comp_link, people, total_clock_format, _| [comp_link, people, total_clock_format] }
  
      [event_name, podiums]
    end
  end  
end
