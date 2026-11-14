require_relative "../core/statistic"

class RecordCountByPerson < Statistic
  def initialize
    @title = "Record count by person"
    @category = :records
    @note = "Each record is counted once, at its highest level: a world record is not counted again as a European or national record."
    @table_header = { "Person" => :left, "Total" => :right, "WR" => :right, "ER" => :right, "NR" => :right }
  end

  def query
    <<-SQL
      SELECT
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link,
        wr_count + er_count + nr_count total_count,
        wr_count,
        er_count,
        nr_count
      FROM (
        SELECT
          r.person_id,
          SUM(IF(r.regional_single_record = 'WR', 1, 0) + IF(r.regional_average_record = 'WR', 1, 0)) wr_count,
          SUM(IF(r.regional_single_record = 'ER', 1, 0) + IF(r.regional_average_record = 'ER', 1, 0)) er_count,
          SUM(IF(r.regional_single_record = 'NR', 1, 0) + IF(r.regional_average_record = 'NR', 1, 0)) nr_count
        FROM results r
        JOIN persons person ON person.wca_id = r.person_id AND person.sub_id = 1 AND person.country_id = 'Poland'
        WHERE r.regional_single_record IN ('NR', 'ER', 'WR') OR r.regional_average_record IN ('NR', 'ER', 'WR')
        GROUP BY r.person_id
      ) AS record_count_by_person
      JOIN persons person ON person.wca_id = person_id AND sub_id = 1
      ORDER BY total_count DESC, wr_count DESC, er_count DESC, person.name
    SQL
  end
end
