require_relative "../core/statistic"

class MostRecordsPerDelegatedCompetition < Statistic
  def initialize
    @title = "Most records per delegated competition"
    @note = "Only Polish delegates included."
    @table_header = {
      "Ratio" => :right,
      "Records" => :right,
      "Competitions" => :right,
      "Delegate" => :left
    }
  end

  def query
    <<-SQL
      SELECT
        FORMAT(stats.total_records / stats.delegated_count, 2) AS ratio,
        stats.total_records,
        stats.delegated_count,
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') AS delegate
      FROM (
        SELECT
          records.delegate_id,
          records.total_records,
          comps.delegated_count
        FROM (
          SELECT
            delegate_id,
            SUM(cnt) AS total_records
          FROM (
            SELECT
              delegate_id,
              record_class,
              SUM(cnt) AS cnt
            FROM (
              SELECT
                cd.delegate_id,
                CASE
                  WHEN r.regional_single_record = 'WR' THEN 'WR'
                  WHEN r.regional_single_record IN ('ER','AfR','AsR','OcR','NAR','SAR') THEN 'CR'
                  WHEN r.regional_single_record = 'NR' THEN 'NR'
                  ELSE NULL
                END AS record_class,
                COUNT(*) AS cnt
              FROM competition_delegates cd
              JOIN results r ON r.competition_id = cd.competition_id
              WHERE r.regional_single_record IS NOT NULL
              GROUP BY cd.delegate_id, record_class

              UNION ALL

              SELECT
                cd.delegate_id,
                CASE
                  WHEN r.regional_average_record = 'WR' THEN 'WR'
                  WHEN r.regional_average_record IN ('ER','AfR','AsR','OcR','NAR','SAR') THEN 'CR'
                  WHEN r.regional_average_record = 'NR' THEN 'NR'
                  ELSE NULL
                END AS record_class,
                COUNT(*) AS cnt
              FROM competition_delegates cd
              JOIN results r ON r.competition_id = cd.competition_id
              WHERE r.regional_average_record IS NOT NULL
              GROUP BY cd.delegate_id, record_class
            ) raw
            GROUP BY delegate_id, record_class
          ) classified
          GROUP BY delegate_id
        ) records
        JOIN (
          SELECT
            delegate_id,
            COUNT(DISTINCT competition_id) AS delegated_count
          FROM competition_delegates
          JOIN competitions competition ON competition.id = competition_id
          WHERE show_at_all = 1 AND cancelled_at IS NULL AND start_date < CURDATE() AND results_posted_at IS NOT NULL
          GROUP BY delegate_id
        ) comps ON comps.delegate_id = records.delegate_id
      ) stats
      JOIN users u ON u.id = stats.delegate_id
      JOIN persons person ON person.wca_id = u.wca_id AND person.sub_id = 1 AND person.country_id = 'Poland'
      ORDER BY (stats.total_records / stats.delegated_count) DESC
      LIMIT 100
    SQL
  end
end
