require_relative "../core/grouped_statistic"

class WinnedWeekCount < GroupedStatistic
  def initialize
    @title = "Winned week count"
    @note = "In other words it's the number of weeks when the given person got the fastest single in the given event."
    @table_header = { "Person" => :left, "Winned weeks" => :right }
  end

  def query
    <<-SQL
      SELECT
        event_id,
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link,
        winned_weeks
      FROM (
        SELECT wb.event_id, r.person_id, COUNT(DISTINCT wb.week_start) AS winned_weeks
        FROM (
          SELECT
            event_id,
            MIN(best) AS week_best,
            DATE_ADD(start_date, INTERVAL(-WEEKDAY(start_date)) DAY) AS week_start
          FROM results
          JOIN competitions competition ON competition.id = competition_id
          WHERE best > 0
          GROUP BY event_id, week_start
        ) wb
        JOIN results r ON r.event_id = wb.event_id AND r.best = wb.week_best
        JOIN competitions c ON c.id = r.competition_id
          AND DATE_ADD(c.start_date, INTERVAL(-WEEKDAY(c.start_date)) DAY) = wb.week_start
        GROUP BY wb.event_id, r.person_id
      ) AS winned_weeks_by_person
      JOIN persons person ON person.wca_id = person_id AND sub_id = 1 AND person.country_id = 'Poland'
    SQL
  end

  def transform(query_results)
    Events::ALL.map do |event_id, event_name|
      results = query_results
        .select { |result| result["event_id"] == event_id }
        .sort_by! do |result|
          -result["winned_weeks"]
        end
        .first(20)
        .map! do |result|
          [result["person_link"], result["winned_weeks"]]
        end
      [event_name, results]
    end
  end
end
