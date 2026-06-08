require_relative "../core/statistic"

class NationalRecordsByPerson < Statistic
  def initialize
    @title = "National records count by person"
    @table_header = { "WRs" => :right, "Person" => :left }
  end

  def query
    <<-SQL
      SELECT
        wrs_count,
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link
      FROM (
        SELECT
          r.person_id,
          SUM(IF(r.regional_single_record = 'NR', 1, 0) + IF(r.regional_average_record = 'NR', 1, 0)) wrs_count
        FROM results r
        JOIN persons person ON person.wca_id = r.person_id AND person.sub_id = 1 AND person.country_id = 'Poland'
        GROUP BY r.person_id
        HAVING wrs_count > 0
      ) AS wrs_count_by_person
      JOIN persons person ON person.wca_id = person_id AND sub_id = 1
      ORDER BY wrs_count DESC, person.name
    SQL
  end
end
