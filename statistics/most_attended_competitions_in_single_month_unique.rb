require_relative "../core/statistic"

class MostAttendedCompetitionsInSingleMonthUnique < Statistic
  def initialize
    @title = "Most attended competitions in a single month (unique)"
    @table_header = { "Competitions" => :right, "Person" => :left, "Month" => :left, "Year" => :left, "List" => :left }
  end

  def query
    <<-SQL
      WITH unique_competitions AS (
        SELECT DISTINCT r.person_id, r.competition_id
        FROM results r
        JOIN persons p ON p.wca_id = r.person_id AND p.sub_id = 1 AND p.country_id = 'Poland'
      ),
      monthly_stats AS (
        SELECT
          uc.person_id,
          MONTH(c.start_date) AS competitions_month,
          YEAR(c.start_date) AS competitions_year,
          COUNT(*) AS attended_within_month,
          GROUP_CONCAT(
            CONCAT('[', c.cell_name, '](https://www.worldcubeassociation.org/competitions/', c.id, ')')
            ORDER BY c.start_date SEPARATOR ', '
          ) AS competition_links
        FROM unique_competitions uc
        JOIN competitions c ON c.id = uc.competition_id
        GROUP BY uc.person_id, MONTH(c.start_date), YEAR(c.start_date)
      )
      SELECT
        ms.attended_within_month,
        CONCAT('[', p.name, '](https://www.worldcubeassociation.org/persons/', p.wca_id, ')') AS person_link,
        MONTHNAME(DATE(CONCAT('2000-', ms.competitions_month, '-01'))) AS month_name,
        ms.competitions_year,
        ms.competition_links
      FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY attended_within_month DESC) AS rn
        FROM monthly_stats
      ) ms
      JOIN persons p ON p.wca_id = ms.person_id AND p.sub_id = 1
      WHERE ms.rn = 1 AND ms.attended_within_month >= 4
      ORDER BY ms.attended_within_month DESC, p.name
    SQL
  end
end
