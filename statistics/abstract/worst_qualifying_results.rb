require_relative "../../core/grouped_statistic"
require_relative "../../core/events"
require_relative "../../core/solve_time"

# Worst results that were still good enough for a given place (a podium, a win, ...).
# Grouped by event, or by year and then by event when +yearly+ is set.
# Fewest Moves is split into separate groups, as its rounds are held in several formats.
class WorstQualifyingResults < GroupedStatistic
  FM_FORMATS = [["m", "Mean of 3"], ["2", "Best of 2"], ["1", "Best of 1"]].freeze

  def initialize(title:, note:, max_position:, joins: "", condition: "", yearly: false)
    @title = title
    @note = note
    @max_position = max_position
    @joins = joins
    @condition = condition
    @yearly = yearly

    @table_header = { "Person" => :left, "Single" => :right, "Average" => :right, "Competition" => :left }
    @table_header["Place"] = :center if @max_position > 1
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
        COALESCE(fm_format.sort_by, format.sort_by) sort_by,
        COALESCE(fm_format.sort_by_second, format.sort_by_second) sort_by_second,
        COALESCE(frf.actual_format_id, results.format_id) actual_format_id,
        results.event_id,
        YEAR(competition.start_date) year,
        results.best single,
        results.average,
        CONCAT('[', results.person_name, '](https://www.worldcubeassociation.org/persons/', results.person_id, ')') person_link,
        CONCAT('[', competition.cell_name, '](https://www.worldcubeassociation.org/competitions/', competition.id, '/results/podiums#e', results.event_id, ')') podium_link,
        results.pos place
      FROM results
      JOIN competitions competition ON competition.id = results.competition_id
      JOIN preferred_formats preferred_format ON preferred_format.event_id = results.event_id AND preferred_format.ranking = 1
      JOIN formats format ON format.id = preferred_format.format_id
      LEFT JOIN fm_round_formats frf ON frf.competition_id = results.competition_id
        AND frf.round_type_id = results.round_type_id
        AND results.event_id = '333fm'
      LEFT JOIN formats fm_format ON fm_format.id = frf.actual_format_id
      #{@joins}
      WHERE results.round_type_id IN ('c', 'f') AND results.pos <= #{@max_position}
        AND NOT (results.round_type_id = 'c' AND EXISTS (
          SELECT 1 FROM results r2
          WHERE r2.competition_id = results.competition_id
            AND r2.event_id = results.event_id
            AND r2.round_type_id = 'f'
        ))
        #{@condition}
    SQL
  end

  def transform(query_results)
    return event_groups(query_results) unless @yearly

    results_by_year = query_results.group_by { |result| result["year"] }
    results_by_year.keys.sort.reverse.map do |year|
      [year.to_s, event_groups(results_by_year[year])]
    end
  end

  def markdown
    return super unless @yearly

    markdown = top
    data.each do |year, groups|
      next if groups.all? { |_, results| results.empty? }
      markdown += "\n### #{year}\n"
      groups.each do |event_name, results|
        next if results.empty?
        markdown += "\n#### #{event_name}\n\n"
        markdown += markdown_table(@table_header, results)
      end
    end
    markdown
  end

  private

  def event_groups(query_results)
    Events::ALL.flat_map do |event_id, event_name|
      if event_id == "333fm"
        FM_FORMATS.map do |format_id, format_label|
          results = query_results.select { |result| result["actual_format_id"] == format_id }
          ["#{event_name} (#{format_label})", top_results(event_id, results)]
        end
      else
        [[event_name, top_results(event_id, query_results)]]
      end
    end
  end

  def top_results(event_id, query_results)
    query_results
      .select { |result| result["event_id"] == event_id }
      .each do |result|
        result["single"] = SolveTime.new(event_id, :single, result["single"])
        result["average"] = SolveTime.new(event_id, :average, result["average"])
      end
      .select { |result| result[result["sort_by"]].complete? }
      .sort_by do |result|
        [result[result["sort_by"]], result[result["sort_by_second"]]]
      end
      .reverse
      .first(10)
      .map do |result|
        result[result["sort_by"]] = "**#{result[result["sort_by"]].clock_format}**"
        result[result["sort_by_second"]] = result[result["sort_by_second"]].clock_format
        row = [result["person_link"], result["single"], result["average"], result["podium_link"]]
        row << result["place"] if @max_position > 1
        row
      end
  end
end
