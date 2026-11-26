require_relative "../../core/grouped_statistic"
require_relative "../../core/events"
require_relative "../../core/solve_time"

class Rankings < GroupedStatistic
  def initialize(title:, note:, condition:)
    @condition = condition

    @title = title
    @category = :results
    @note = note
    @table_header = { "Person" => :left, "Result" => :right, "Competition" => :left, "Details" => :left }
  end

  def query
    <<-SQL
      SELECT
        r.id result_id,
        r.event_id,
        r.best single,
        r.average,
        ra.value,
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link,
        CONCAT('[', competition.cell_name, '](https://www.worldcubeassociation.org/competitions/', competition.id, ')') competition_link,
        competition.start_date
      FROM results r
      JOIN result_attempts ra ON ra.result_id = r.id
      JOIN persons person
        ON person.wca_id = r.person_id
        AND person.sub_id = 1
        AND person.country_id = 'Poland'
      JOIN competitions competition ON competition.id = r.competition_id
      #{@condition}
      ORDER BY r.event_id, r.id, ra.attempt_number
    SQL
  end

  def transform(query_results)
    results_by_event = query_results
      .group_by { |row| row["result_id"] }
      .values
      .group_by { |attempts| attempts.first["event_id"] }

    Events::ALL.flat_map do |event_id, event_name|
      event_results = results_by_event.fetch(event_id, [])
      %w(single average).map do |type|
        rows = event_results
          .select { |attempts| attempts.first[type] > 0 }
          .group_by { |attempts| attempts.first["person_link"] }
          .map { |_person_link, results| results.min_by { |attempts| [attempts.first[type], attempts.first["start_date"]] } }
          .sort_by { |attempts| [attempts.first[type], attempts.first["start_date"]] }
          .first(10)
          .map do |attempts|
            result = attempts.first
            main_result = SolveTime.new(event_id, type.to_sym, result[type])
            result_details = attempts
              .map { |attempt| SolveTime.new(event_id, :single, attempt["value"]).clock_format }
              .reject(&:empty?)
              .join(', ')
            [result["person_link"], "**#{main_result.clock_format}**", result["competition_link"], result_details]
          end
        ["#{event_name} - #{type.capitalize}", rows]
      end
    end
  end
end
