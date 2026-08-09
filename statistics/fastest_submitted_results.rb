require_relative "../core/statistic"

class FastestSubmittedResults < Statistic
  def initialize
    @title = "Fastest submitted results"
    @note = "Only Polish competitions are included."
    @table_header = { "Competition" => :left, "Time to submit" => :right, "Delegates" => :left }
  end

  def query
    <<-SQL
      SELECT 
          c.id,
          c.name,
          TIMESTAMPDIFF(SECOND, (
              SELECT sa.end_time 
              FROM schedule_activities sa 
              JOIN venue_rooms vr ON sa.venue_room_id = vr.id
              JOIN competition_venues cv ON vr.competition_venue_id = cv.id
              WHERE cv.competition_id = c.id 
              ORDER BY sa.end_time DESC 
              LIMIT 1
          ), c.results_submitted_at) AS diff_in_seconds, 
          GROUP_CONCAT(
              DISTINCT CASE 
                  WHEN d.wca_id IS NOT NULL THEN CONCAT('[', d.name, '](https://www.worldcubeassociation.org/persons/', d.wca_id, ')')
                  ELSE d.name 
              END
              ORDER BY d.name
              SEPARATOR ', '
          ) AS delegates
      FROM 
          competitions c
      LEFT JOIN 
          competition_delegates cd ON cd.competition_id = c.id
      LEFT JOIN 
          users d ON cd.delegate_id = d.id
      WHERE 
          c.country_id = 'Poland'
          AND c.results_submitted_at IS NOT NULL
      GROUP BY 
          c.id, c.name, c.results_submitted_at
      HAVING 
          diff_in_seconds IS NOT NULL
      ORDER BY 
          diff_in_seconds ASC, c.name ASC
      LIMIT 20;
    SQL
  end

  def transform(query_results)
    query_results.map do |row|
      time = format_time(row["diff_in_seconds"])
      comp_link = "[#{row["name"]}](https://www.worldcubeassociation.org/competitions/#{row["id"]})"
      
      [comp_link, time, row["delegates"]]
    end
  end

  private

  def format_time(seconds)
    return "" unless seconds
    
    prefix = ""
    if seconds < 0
      prefix = "-"
      seconds = -seconds
    end

    days = seconds / 86400
    hours = (seconds % 86400) / 3600
    minutes = (seconds % 3600) / 60

    parts = []
    parts << "#{days}d" if days > 0
    parts << "#{hours}h" if hours > 0
    parts << "#{minutes}m" if minutes > 0 || parts.empty?
    
    "#{prefix}#{parts.join(' ')}"
  end
end
