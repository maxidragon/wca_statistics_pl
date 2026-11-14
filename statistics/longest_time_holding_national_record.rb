require_relative "abstract/national_record_periods"

class LongestTimeHoldingNationalRecord < NationalRecordPeriods
  def initialize
    @title = "Longest time holding a national record"
    @category = :records
    @note = "How long a person held a Polish national record without a break. Improving on your own record keeps the streak going, " \
      "a record from someone else ends it. Continental and world records set by Poles count as national records as well. " \
      "A streak with no end date is still going, and its days are counted up to today."
    @table_header = { "Person" => :left, "Event" => :left, "Type" => :left, "Records" => :right, "Best result" => :right, "Start date" => :left, "End date" => :left, "Days" => :right }
  end

  def transform(query_results)
    records(query_results)
      .group_by { |record| [record[:person_id], record[:event], record[:type]] }
      .flat_map { |_, person_records| streaks(person_records) }
      .sort_by { |streak| -days(streak[:start_date], streak[:end_date]) }
      .take(50)
      .map do |streak|
        first, last = streak[:records].first, streak[:records].last
        [
          first[:person_link],
          first[:event],
          first[:type],
          streak[:records].size,
          last[:result],
          format_date(streak[:start_date]),
          format_date(streak[:end_date]),
          "**#{days(streak[:start_date], streak[:end_date])}**"
        ]
      end
  end

  private

  # Splits one person's records in one event into unbroken streaks.
  # A streak ends with the first of its records that someone else improved on, or never if none was.
  def streaks(person_records)
    person_records.slice_when do |record, _next_record|
      record[:beaten_by] && record[:beaten_by][:person_id] != record[:person_id]
    end.map do |records|
      last = records.last
      ended_by_other = last[:beaten_by] && last[:beaten_by][:person_id] != last[:person_id]
      {
        records: records,
        start_date: records.first[:start_date],
        end_date: ended_by_other ? last[:beaten_by][:start_date] : nil
      }
    end
  end
end
