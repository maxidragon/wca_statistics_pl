require_relative "../core/grouped_statistic"
require_relative "../core/events"
require_relative "../core/solve_time"

class NrAveragesWithAllAttemptsSubPreviousNr < GroupedStatistic
  RECORD_IDS = %w(NR AfR AsR NAR SAR ER OcR WR)

  def initialize
    @title = "National record averages with every attempt better than the previous national record average"
    @note = "Continental and world records count as national records as well. The first national record in an event is skipped, as there is nothing to compare it with. Averages with an unsolved attempt are not taken into account."
    @table_header = { "Average" => :right, "Times" => :left, "Previous NR" => :right, "Person" => :left, "Competition" => :left }
  end

  def query
    <<-SQL
      SELECT
        r.event_id,
        r.average,
        GROUP_CONCAT(ra.value ORDER BY ra.attempt_number) attempts,
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link,
        CONCAT('[', competition.cell_name, '](https://www.worldcubeassociation.org/competitions/', competition.id, '/results/by_person#', person.wca_id, ')') results_link
      FROM results r
      JOIN result_attempts ra ON ra.result_id = r.id
      JOIN persons person ON person.wca_id = r.person_id AND person.sub_id = 1
      JOIN competitions competition ON competition.id = r.competition_id
      JOIN round_types round_type ON round_type.id = r.round_type_id
      WHERE r.regional_average_record IN (#{RECORD_IDS.map { |record_id| "'#{record_id}'" }.join(', ')})
        AND r.country_id = 'Poland'
        AND r.average > 0
      GROUP BY r.id
      ORDER BY competition.start_date, round_type.rank
    SQL
  end

  def transform(query_results)
    results_by_event = query_results.group_by { |result| result["event_id"] }
    Events::ALL.map do |event_id, event_name|
      results = results_by_event[event_id] || []
      previous_record = nil
      # The results are ordered chronologically, so the records are collected in the same order and reversed afterwards.
      rows = results.each_with_object([]) do |result, rows|
        record = previous_record
        previous_record = [previous_record, result["average"]].compact.min
        next if record.nil?
        attempts = result["attempts"].split(',').map!(&:to_i)
        next if attempts.any? { |attempt| attempt <= 0 } # DNF, DNS or a skipped attempt
        # For 333fm the average is stored multiplied by 100, while attempts are plain move counts.
        scale = event_id == "333fm" ? 100 : 1
        next unless attempts.all? { |attempt| attempt * scale < record }
        times = attempts.map { |attempt| SolveTime.new(event_id, :single, attempt).clock_format }
        rows << [
          "**#{SolveTime.new(event_id, :average, result['average']).clock_format}**",
          times.join(', '),
          SolveTime.new(event_id, :average, record).clock_format,
          result["person_link"],
          result["results_link"],
        ]
      end
      [event_name, rows.reverse!]
    end
  end
end
