require_relative "../core/grouped_statistic"
require_relative "../core/solve_time"

class WorldAndEuropeanRecords < GroupedStatistic
  def initialize
    @title = "World and European records set by Polish people"
    @note = "All historical records are taken into account (i.e. not only the current ones). Records that were world records at the time are listed only in the world records table."
    @table_header = { "Date" => :left, "Event" => :left, "Type" => :left, "Result" => :right, "Person" => :left, "Competition" => :left }
  end

  def query
    <<-SQL
      SELECT
        regional_single_record,
        regional_average_record,
        best single,
        average,
        result.event_id event_id,
        event.name event_name,
        competition.start_date competition_date,
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link,
        CONCAT('[', competition.cell_name, '](https://www.worldcubeassociation.org/competitions/', competition.id, '/results/by_person#', person.wca_id, ')') results_link
      FROM results result
      JOIN persons person ON person.wca_id = result.person_id AND person.sub_id = 1 AND person.country_id = 'Poland'
      JOIN competitions competition ON competition.id = result.competition_id
      JOIN events event ON event.id = result.event_id
      WHERE regional_single_record IN ('WR', 'ER')
         OR regional_average_record IN ('WR', 'ER')
      ORDER BY competition_date DESC, event.rank
    SQL
  end

  def transform(query_results)
    {
      "World records" => %w(WR),
      "European records" => %w(ER)
    }.map do |header, record_ids|
      records = query_results.flat_map do |result|
        %w(single average)
          .select { |type| record_ids.include?(result["regional_#{type}_record"]) }
          .map! do |type|
            solve_time = SolveTime.new(result["event_id"], type, result[type])
            [
              result["competition_date"].strftime("%e %b %Y"),
              result["event_name"],
              type.capitalize,
              solve_time.clock_format,
              result["person_link"],
              result["results_link"]
            ]
          end
      end
      [header, records]
    end
  end
end
