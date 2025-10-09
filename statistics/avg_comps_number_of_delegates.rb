require_relative "../core/statistic"

class AvgCompsNumberOfDelegates < Statistic
  def initialize
    @title = "Average number of competitions of listed delegates at Polish competitions"
    @note = "Number of competitions is counted up to and including the competition where the person was a delegate. Only competitions with more than one delegate are included in the average."
    @table_header = {  "Competition" => :left, "Delegates" => :right, "Average number of competitions of listed delegates" => :right, }
  end

  def query
    <<-SQL
WITH delegate_person AS (
  SELECT
    u.id AS delegate_id,
    u.name,
    u.wca_id AS person_id
  FROM users u
  WHERE u.wca_id IS NOT NULL
),
delegate_competitions AS (
  SELECT
    cd.competition_id,
    cd.delegate_id,
    c.name AS competition_name,
    c.end_date
  FROM competition_delegates cd
  JOIN competitions c ON c.id = cd.competition_id
  WHERE c.country_id = 'Poland' AND c.cancelled_at IS NULL AND c.results_posted_at IS NOT NULL
),
delegate_stats AS (
  SELECT
    dc.competition_id,
    dc.delegate_id,
    COUNT(DISTINCT r.competition_id) AS competitions_as_competitor
  FROM delegate_competitions dc
  JOIN delegate_person dp ON dp.delegate_id = dc.delegate_id
  JOIN competitions c2 ON c2.end_date <= dc.end_date
  JOIN results r ON r.competition_id = c2.id AND r.person_id = dp.person_id
  GROUP BY dc.competition_id, dc.delegate_id
)
SELECT
  CONCAT(
    '[', competition.cell_name, '](https://www.worldcubeassociation.org/competitions/', competition.id, ')'
  ) AS competition_link,
  GROUP_CONCAT(
    DISTINCT CONCAT(
      CASE
      WHEN dp.person_id IS NOT NULL THEN CONCAT('[', dp.name, '](https://www.worldcubeassociation.org/persons/', dp.person_id, ')')
      ELSE dp.name
      END
      )
      ORDER BY dp.name SEPARATOR ', '
      ) AS delegates,
      FORMAT(ROUND(AVG(ds.competitions_as_competitor), 2), 2) AS formatted_avg_competitions_before_delegating
FROM delegate_competitions dc
JOIN delegate_stats ds ON ds.competition_id = dc.competition_id
JOIN delegate_person dp ON dp.delegate_id = dc.delegate_id
JOIN competitions competition ON competition.id = dc.competition_id
GROUP BY dc.competition_id, dc.competition_name
HAVING COUNT(DISTINCT dp.delegate_id) > 1
ORDER BY ROUND(AVG(ds.competitions_as_competitor), 2)
 DESC;
    SQL
  end
end
