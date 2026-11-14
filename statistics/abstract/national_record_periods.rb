require "date"
require_relative "../../core/statistic"
require_relative "../../core/events"
require_relative "../../core/solve_time"

# Every Polish national record with the period it stood for.
# A continental or world record set by a Pole is a national record too.
class NationalRecordPeriods < Statistic
  DATE_FORMAT = "%e&nbsp;%b&nbsp;%Y"

  def query
    <<-SQL
      SELECT
        regional_single_record,
        regional_average_record,
        best single,
        average,
        person.wca_id person_id,
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link,
        CONCAT('[', competition.cell_name, '](https://www.worldcubeassociation.org/competitions/', competition.id, '/results/by_person#', person.wca_id, ')') results_link,
        competition.start_date competition_date,
        event_id
      FROM results result
      JOIN persons person ON person.wca_id = person_id AND person.sub_id = 1
      JOIN competitions competition ON competition.id = competition_id
      WHERE (regional_single_record IN ('NR', 'ER', 'WR') OR regional_average_record IN ('NR', 'ER', 'WR'))
        AND result.country_id = 'Poland'
      ORDER BY competition_date
    SQL
  end

  # One hash per record. `beaten_by` is the record that first improved on it, nil while it still stands.
  def records(query_results)
    %w(single average).flat_map do |type|
      query_results
        .select do |result|
          %w(NR ER WR).include?(result["regional_#{type}_record"]) &&
          Events::OFFICIAL.has_key?(result["event_id"])
        end
        .group_by { |result| result["event_id"] }
        .flat_map do |event_id, results|
          records = results.map do |result|
            {
              person_id: result["person_id"],
              person_link: result["person_link"],
              results_link: result["results_link"],
              event: Events::ALL[event_id],
              type: type.capitalize,
              value: result[type],
              result: SolveTime.new(event_id, type, result[type]).clock_format,
              start_date: result["competition_date"]
            }
          end
          # On the same day records come from successive rounds, so the worse one was set first.
          records.sort_by! { |record| [record[:start_date], -record[:value]] }
          records.each do |record|
            better = records.select { |other| other[:value] < record[:value] }
            first_date = better.map { |other| other[:start_date] }.min
            # Several records on the same day happen in successive rounds, so the smallest improvement came first.
            record[:beaten_by] = better.select { |other| other[:start_date] == first_date }.max_by { |other| other[:value] }
          end
          records
        end
    end
  end

  def days(start_date, end_date)
    ((end_date || Date.today) - start_date).to_i
  end

  def format_date(date)
    date&.strftime(DATE_FORMAT)
  end
end
