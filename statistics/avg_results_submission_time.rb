require_relative "../core/statistic"

class AvgResultsSubmissionTime < Statistic
  def initialize
    @title = "Average results submission time by Polish delegates"
    @table_header = { "Delegate" => :right, "Average time" => :left}
  end

  def query
    <<-SQL
      SELECT
    CASE 
    WHEN d.wca_id IS NOT NULL THEN CONCAT('[', d.name, '](https://www.worldcubeassociation.org/persons/', d.wca_id, ')')
    ELSE d.name 
    END as delegate_name,
    AVG(TIMESTAMPDIFF(SECOND, (
        SELECT sa.end_time
        FROM schedule_activities sa
        JOIN venue_rooms vr ON sa.venue_room_id = vr.id
        JOIN competition_venues cv ON vr.competition_venue_id = cv.id
        WHERE cv.competition_id = c.id
        ORDER BY sa.end_time DESC
        LIMIT 1
    ), c.results_submitted_at) / 3600) AS avg_submission_time_hours
FROM 
    competitions c
JOIN 
    competition_delegates cd ON cd.competition_id = c.id
JOIN 
    users d ON cd.delegate_id = d.id AND d.country_iso2 = 'PL'
WHERE 
    c.results_submitted_at IS NOT NULL
GROUP BY 
    d.id, d.name
HAVING 
    avg_submission_time_hours IS NOT NULL
ORDER BY 
    avg_submission_time_hours ASC;
    SQL
  end
end
