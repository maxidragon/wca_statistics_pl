require_relative "abstract/national_record_periods"

class LongestStandingRecords < NationalRecordPeriods
  def initialize
    @title = "Longest standing records"
    @category = :records
    @note = "Polish national records, sorted by how long they stood. Continental and world records set by Poles count as national records as well. " \
      "A record with no end date still stands, and its days are counted up to today."
    @table_header = { "Person" => :left, "Event" => :left, "Type" => :left, "Result" => :right, "Start date" => :left, "End date" => :left, "Days" => :right, "Competition" => :left }
  end

  def transform(query_results)
    records(query_results)
      .map { |record| record.merge(end_date: record[:beaten_by]&.fetch(:start_date)) }
      .sort_by { |record| -days(record[:start_date], record[:end_date]) }
      .take(50)
      .map do |record|
        [
          record[:person_link],
          record[:event],
          record[:type],
          record[:result],
          format_date(record[:start_date]),
          format_date(record[:end_date]),
          "**#{days(record[:start_date], record[:end_date])}**",
          record[:results_link]
        ]
      end
  end
end
