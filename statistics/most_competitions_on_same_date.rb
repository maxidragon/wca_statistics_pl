require_relative "../core/statistic"

class MostCompetitionsOnSameDate < Statistic
  def initialize
    @title = "Most competitions on the same calendar date"
    @table_header = { "Count" => :right, "Person" => :left, "Date" => :left, "Years" => :left }
  end

  def query
    <<-SQL
      SELECT
        pd.cnt,
        CONCAT('[', p.name, '](https://www.worldcubeassociation.org/persons/', pd.person_id, ')') AS person_link,
        pd.competition_date,
        pd.years
      FROM (
        SELECT
          person_id,
          competition_date,
          COUNT(*) AS cnt,
          GROUP_CONCAT(comp_year ORDER BY comp_year SEPARATOR ', ') AS years
        FROM (
          SELECT DISTINCT
            r.person_id,
            DATE_FORMAT(cd.competition_date, '%e %M') AS competition_date,
            r.competition_id,
            YEAR(cd.competition_date) AS comp_year
          FROM results r
          JOIN persons p ON p.wca_id = r.person_id AND p.sub_id = 1 AND p.country_id = 'Poland'
          JOIN (
            SELECT
              c.id AS competition_id,
              DATE_ADD(c.start_date, INTERVAL n.num DAY) AS competition_date
            FROM competitions c
            JOIN (
              SELECT 0 AS num UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
                   UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
            ) n
            WHERE DATE_ADD(c.start_date, INTERVAL n.num DAY) <= c.end_date
          ) cd ON cd.competition_id = r.competition_id
        ) deduped
        GROUP BY person_id, competition_date
      ) pd
      JOIN persons p ON p.wca_id = pd.person_id AND p.sub_id = 1
      ORDER BY pd.cnt DESC, p.name
      LIMIT 50
    SQL
  end

  def transform(query_results)
    query_results.map do |result|
      [result["cnt"], result["person_link"], result["competition_date"], result["years"]]
    end
  end
end
