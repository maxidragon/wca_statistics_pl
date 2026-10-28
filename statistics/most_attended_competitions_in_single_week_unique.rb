require_relative "../core/statistic"

class MostAttendedCompetitionsInSingleWeekUnique < Statistic
  def initialize
    @title = "Most attended competitions in a single week (unique)"
    @category = :competing
    @table_header = { "Competitions" => :right, "Person" => :left, "Start date" => :left, "End date" => :left, "List" => :left }
  end

  def query
    <<-SQL
      WITH unique_competitions AS (
        SELECT DISTINCT r.person_id, r.competition_id
        FROM results r
        JOIN persons p ON p.wca_id = r.person_id AND p.sub_id = 1 AND p.country_id = 'Poland'
      ),
      weekly_stats AS (
        SELECT
          uc.person_id,
          DATE_ADD(c.start_date, INTERVAL(-WEEKDAY(c.start_date)) DAY) AS week_start_date,
          DATE_ADD(c.start_date, INTERVAL(6-WEEKDAY(c.start_date)) DAY) AS week_end_date,
          COUNT(*) AS attended_within_week,
          GROUP_CONCAT(
            CONCAT('[', c.cell_name, '](https://www.worldcubeassociation.org/competitions/', c.id, ')')
            ORDER BY c.start_date SEPARATOR ', '
          ) AS competition_links
        FROM unique_competitions uc
        JOIN competitions c ON c.id = uc.competition_id
        GROUP BY uc.person_id, week_start_date, week_end_date
      )
      SELECT
        ws.attended_within_week,
        CONCAT('[', p.name, '](https://www.worldcubeassociation.org/persons/', p.wca_id, ')') AS person_link,
        ws.week_start_date,
        ws.week_end_date,
        ws.competition_links
      FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY attended_within_week DESC, week_start_date) AS rn
        FROM weekly_stats
      ) ws
      JOIN persons p ON p.wca_id = ws.person_id AND p.sub_id = 1
      WHERE ws.rn = 1 AND ws.attended_within_week >= 3
      ORDER BY ws.attended_within_week DESC, p.name
    SQL
  end

  def transform(query_results)
    query_results.map do |result|
      date_format = "%e&nbsp;%b&nbsp;%Y"
      week_start = result["week_start_date"].strftime(date_format)
      week_end = result["week_end_date"].strftime(date_format)
      [result["attended_within_week"], result["person_link"], week_start, week_end, result["competition_links"]]
    end
  end
end
