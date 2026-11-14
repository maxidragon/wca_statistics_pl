require_relative "../core/statistic"

class NationalRecordsByPerson < Statistic
  def initialize
    @title = "National records count by person"
    @category = :records
    @note = "Continental and world records set by Poles count as national records as well."
    @table_header = { "NRs" => :right, "Person" => :left }
  end

  def query
    <<-SQL
      SELECT
        nrs_count,
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link
      FROM (
        SELECT
          r.person_id,
          SUM(IF(r.regional_single_record IN ('NR', 'ER', 'WR'), 1, 0) + IF(r.regional_average_record IN ('NR', 'ER', 'WR'), 1, 0)) nrs_count
        FROM results r
        JOIN persons person ON person.wca_id = r.person_id AND person.sub_id = 1 AND person.country_id = 'Poland'
        GROUP BY r.person_id
        HAVING nrs_count > 0
      ) AS nrs_count_by_person
      JOIN persons person ON person.wca_id = person_id AND sub_id = 1
      ORDER BY nrs_count DESC, person.name
    SQL
  end
end
