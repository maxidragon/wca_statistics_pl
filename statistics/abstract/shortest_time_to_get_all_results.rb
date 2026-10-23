require_relative "../../core/grouped_statistic"
require_relative "../../core/events"

# Measures how long it took a person to go from their first competition
# to having a result in every official event, separately for each period
# in which the set of official events stayed the same.
class ShortestTimeToGetAllResults < GroupedStatistic
  # Before this only 3x3x3 was held, which would make a single 1982 competition a complete set.
  COUNTED_FROM = Date.new(2003, 8, 23)

  Period = Struct.new(:from, :to, :event_ids) do
    def include?(date)
      from <= date && (to.nil? || date < to)
    end

    def name
      return "Since #{format_date(from)}" if to.nil?
      "#{format_date(from)} – #{format_date(to - 1)}"
    end

    private

    def format_date(date)
      date.strftime("%-d %B %Y")
    end
  end

  def initialize(with_averages:)
    @with_averages = with_averages
    @title = with_averages ? "Shortest time to get all singles and averages" : "Shortest time to get all singles"
    @category = :milestones
    @note = "Each table covers a period in which the set of official events didn't change. A person is listed when they had a result in every event of that period on one of their competition days within it. Days are counted from their first competition."
    @table_header = { "Days" => :right, "Person" => :left }
  end

  def query
    <<-SQL
      SELECT
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link,
        competition.start_date,
        result.event_id,
        MAX(result.best > 0) has_single,
        MAX(result.average > 0) has_average
      FROM results result
      JOIN persons person ON person.wca_id = result.person_id AND person.sub_id = 1 AND person.country_id = 'Poland'
      JOIN competitions competition ON competition.id = result.competition_id
      GROUP BY person.wca_id, person.name, competition.start_date, result.event_id
      ORDER BY competition.start_date
    SQL
  end

  def transform(query_results)
    periods = official_periods
    rows_by_period = Hash.new { |hash, period| hash[period] = [] }
    query_results
      .group_by { |result| result["person_link"] }
      .each do |person_link, results|
        first_competition_date = results[0]["start_date"]
        completion_dates(results, periods).each do |period, date|
          rows_by_period[period] << [(date - first_competition_date).to_i, person_link]
        end
      end
    periods.reverse.map do |period|
      events = period.event_ids.map { |event_id| Events::ALL[event_id] }.join(", ")
      [period.name, rows_by_period[period].sort_by { |days, person_link| days }, @table_header, "Events: #{events}"]
    end
  end

  private

  # Splits the time since COUNTED_FROM wherever an event was added or removed.
  def official_periods
    boundaries = Events::OFFICIAL_PERIODS.values.flatten.compact.select { |date| date > COUNTED_FROM }
    starts = [COUNTED_FROM, *boundaries].uniq.sort
    starts.each_with_index.map do |from, index|
      Period.new(from, starts[index + 1], Events.official_on(from))
    end
  end

  # For each period, the first of the person's competition days within it
  # after which they have every result required in that period.
  def completion_dates(results, periods)
    achieved = Set.new
    completed = {}
    results
      .chunk_while { |previous, current| previous["start_date"] == current["start_date"] }
      .each do |day_results|
        day_results.each do |result|
          achieved << [result["event_id"], :single] if result["has_single"] == 1
          achieved << [result["event_id"], :average] if @with_averages && result["has_average"] == 1
        end
        date = day_results[0]["start_date"]
        period = periods.find { |period| period.include?(date) }
        next if period.nil? || completed.key?(period)
        completed[period] = date if required_results(period).subset?(achieved)
      end
    completed
  end

  def required_results(period)
    period.event_ids.flat_map do |event_id|
      types = [:single]
      types << :average if @with_averages && !Events::WITHOUT_AVERAGE.include?(event_id)
      types.map { |type| [event_id, type] }
    end.to_set
  end
end
