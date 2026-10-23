require_relative "../core/grouped_statistic"
require_relative "../core/events"

class MostSolvesInEvent < GroupedStatistic
  def initialize
    @title = "Most solves in an event"
    @category = :results
    @note = "Counts completed solves (not DNF) across all competitions. Attempts include completed solves and DNFs, DNS are excluded."
    @table_header = { "Person" => :left, "Solves" => :right, "Attempts" => :right }
  end

  def query
    <<-SQL
      SELECT
        r.event_id,
        CONCAT('[', p.name, '](https://www.worldcubeassociation.org/persons/', p.wca_id, ')') AS person_link,
        SUM(CASE WHEN ra.value > 0 THEN 1 ELSE 0 END) AS completed_count,
        SUM(CASE WHEN ra.value = -1 THEN 1 ELSE 0 END) AS dnfs_count
      FROM results r
      JOIN persons p ON p.wca_id = r.person_id AND p.sub_id = 1 AND p.country_id = 'Poland'
      JOIN result_attempts ra ON ra.result_id = r.id
      GROUP BY r.event_id, r.person_id, person_link
    SQL
  end

  def transform(query_results)
    results_by_event = query_results.group_by { |result| result["event_id"] }
    Events::ALL.map do |event_id, event_name|
      results = results_by_event.fetch(event_id, [])
        .map do |result|
          completed_count = result["completed_count"]
          attempts_count = completed_count + result["dnfs_count"] # Completed and DNFs.
          [result["person_link"], completed_count, attempts_count]
        end
        .select { |_, completed_count, _| completed_count > 0 }
        .sort_by! { |person_link, completed_count, attempts_count| [-completed_count, attempts_count, person_link] }
        .first(20)
        .map! { |person_link, completed_count, attempts_count| [person_link, "**#{completed_count}**", attempts_count] }
      [event_name, results]
    end
  end
end
