require_relative "../core/grouped_statistic"

class MostCompletedSolves < GroupedStatistic
  def initialize
    @title = "Most completed solves"
    @table_header = { "" => :left, "Solves" => :right, "Attempts" => :right }
  end

  def query
    <<-SQL
      WITH polish_results AS (
        SELECT r.id, r.competition_id, r.event_id,
          CONCAT('[', p.name, '](https://www.worldcubeassociation.org/persons/', p.wca_id, ')') AS person_link
        FROM results r
        JOIN persons p ON p.wca_id = r.person_id AND p.sub_id = 1 AND p.country_id = 'Poland'
      )
      SELECT
        SUM(CASE WHEN ra.value > 0 THEN 1 ELSE 0 END) AS completed_count,
        SUM(CASE WHEN ra.value = -1 THEN 1 ELSE 0 END) AS dnfs_count,
        CONCAT('[', c.cell_name, '](https://www.worldcubeassociation.org/competitions/', c.id, ')') AS competition_link,
        pr.person_link,
        YEAR(c.start_date) AS year,
        e.name AS event
      FROM polish_results pr
      JOIN result_attempts ra ON ra.result_id = pr.id
      JOIN competitions c ON c.id = pr.competition_id
      JOIN events e ON e.id = pr.event_id
      GROUP BY pr.id
    SQL
  end

  def transform(query_results)
    {
      "Competition" => "competition_link",
      "Person" => "person_link",
      "Year" => "year",
      "Event" => "event"
    }.map do |group_name, group_field|
      count_by_group = query_results
        .group_by { |result| result[group_field] }
        .map do |group_value, results|
          completed_count = results.sum { |result| result["completed_count"] }
          attempts_count = completed_count + results.sum { |result| result["dnfs_count"] } # Completed and DNFs.
          [group_value, completed_count, attempts_count]
        end
        .sort_by! { |group_value, completed_count, attempts_count| [-completed_count, attempts_count, group_value] }
        .first(20)
        .map! { |group_value, completed_count, attempts_count| [group_value, "**#{completed_count}**", attempts_count] }
      [group_name, count_by_group]
    end
  end
end
