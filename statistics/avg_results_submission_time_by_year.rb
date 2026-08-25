require_relative "../core/grouped_statistic"

class AvgResultsSubmissionTimeByYear < GroupedStatistic
  def initialize
    @title = "Average results submission time by Polish delegates each year"
    @table_header = { "Delegate" => :right, "Average time" => :left, "Total delegated" => :right }
  end

  def query
    <<-SQL
SELECT
    YEAR(c.start_date) AS year,
    CASE
        WHEN d.wca_id IS NOT NULL THEN CONCAT('[', d.name, '](https://www.worldcubeassociation.org/persons/', d.wca_id, ')')
        ELSE d.name
    END AS delegate_name,
    AVG(TIMESTAMPDIFF(SECOND, last_activity.end_time, c.results_submitted_at)) AS avg_submission_seconds,
    COUNT(DISTINCT c.id) AS delegated_competitions
FROM
    competitions c
JOIN
    competition_delegates cd ON cd.competition_id = c.id
JOIN
    users d ON cd.delegate_id = d.id AND d.country_iso2 = 'PL'
LEFT JOIN (
    SELECT cv.competition_id, MAX(sa.end_time) AS end_time
    FROM schedule_activities sa
    JOIN venue_rooms vr ON sa.venue_room_id = vr.id
    JOIN competition_venues cv ON vr.competition_venue_id = cv.id
    GROUP BY cv.competition_id
) last_activity ON last_activity.competition_id = c.id
WHERE
    c.results_submitted_at IS NOT NULL
    AND c.country_id NOT IN ('XA', 'XE', 'XF', 'XM', 'XN', 'XO', 'XS', 'XW')
GROUP BY
    year, d.id, d.name, d.wca_id
HAVING
    avg_submission_seconds IS NOT NULL
ORDER BY
    year DESC, avg_submission_seconds ASC;
    SQL
  end

  def transform(query_results)
    query_results
      .group_by { |row| row["year"] }
      .map do |year, rows|
        delegate_rows = rows.map do |row|
          [row["delegate_name"], format_duration(row["avg_submission_seconds"] / 3600.0), row["delegated_competitions"]]
        end
        [year, delegate_rows]
      end
  end

  private

  def format_duration(hours)
    return "%.2fh" % hours if hours.abs < 24

    sign = hours.negative? ? "-" : ""
    "#{sign}#{(hours.abs / 24).floor}d %.2fh" % (hours.abs.round(2) % 24)
  end
end
