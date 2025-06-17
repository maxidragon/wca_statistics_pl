require_relative "../core/statistic"

class MostAttendedCompetitionsInSingleMonthUnique < Statistic
  def initialize
    @title = "Most attended competitions in a single month (unique)"
    @table_header = { "Competitions" => :right, "Person" => :left, "Month" => :left, "Year" => :left, "List" => :left }
  end
  def query
    <<-SQL
      WITH unique_competitions AS (
        SELECT DISTINCT person_id, competition_id
        FROM results
      ),
      counted_competitions AS (
        SELECT
          uc.person_id,
          MONTHNAME(c.start_date) AS month_name,
          YEAR(c.start_date) AS competitions_year,
          COUNT(*) AS attended_within_month,
          (
            SELECT GROUP_CONCAT(competition_link ORDER BY start_date)
            FROM (
              SELECT 
                CONCAT('[', c2.cell_name, '](https://www.worldcubeassociation.org/competitions/', c2.id, ')') AS competition_link,
                c2.start_date
              FROM unique_competitions uc2
              JOIN competitions c2 ON c2.id = uc2.competition_id
              WHERE uc2.person_id = uc.person_id AND
                    MONTH(c2.start_date) = MONTH(c.start_date) AND
                    YEAR(c2.start_date) = YEAR(c.start_date)
              GROUP BY c2.id, c2.cell_name, c2.start_date
            ) AS links
          ) AS competition_links
        FROM unique_competitions uc
        JOIN competitions c ON c.id = uc.competition_id
        GROUP BY uc.person_id, MONTHNAME(c.start_date), YEAR(c.start_date)
      ),
      ranked_competitions AS (
        SELECT
          *,
          ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY attended_within_month DESC) AS rn
        FROM counted_competitions
      )
      SELECT
        rc.attended_within_month,
        CONCAT('[', p.name, '](https://www.worldcubeassociation.org/persons/', p.wca_id, ')') AS person_link,
        rc.month_name,
        rc.competitions_year,
        rc.competition_links
      FROM ranked_competitions rc
      JOIN persons p ON p.wca_id = rc.person_id AND p.sub_id = 1 AND p.country_id = 'Poland'
      WHERE rc.rn = 1 AND rc.attended_within_month >= 4
      ORDER BY rc.attended_within_month DESC, p.name
    SQL
  end  
end
