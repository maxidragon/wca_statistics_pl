require_relative "../core/grouped_statistic"
require_relative "../core/events"

class BestMedalCollectionByEvent < GroupedStatistic
  def initialize
    @title = "Best medal collection by event"
    @note = "All medals are taken into account, no matter where the competition was held."
    @table_header = { "Total" => :center, "Person" => :left, "Gold" => :center, "Silver" => :center, "Bronze" => :center }
  end

  def query
    <<-SQL
      SELECT
        event_id,
        CONCAT('**', gold_medals + silver_medals + bronze_medals, '**') total,
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link,
        gold_medals,
        silver_medals,
        bronze_medals
      FROM (
        SELECT
          person_id,
          event_id,
          SUM(IF(pos = 1, 1, 0)) gold_medals,
          SUM(IF(pos = 2, 1, 0)) silver_medals,
          SUM(IF(pos = 3, 1, 0)) bronze_medals
        FROM results result
        WHERE 1
          AND round_type_id IN ('c', 'f')
          AND best > 0
          AND pos IN (1, 2, 3)
          AND result.country_id = 'Poland'
        GROUP BY person_id, event_id
      ) AS medals_by_event
      JOIN persons person ON person.wca_id = person_id AND sub_id = 1
      ORDER BY event_id, gold_medals + silver_medals + bronze_medals DESC, gold_medals DESC, silver_medals DESC, bronze_medals DESC, person.name
    SQL
  end

  def transform(query_results)
    medals_by_event = query_results.group_by { |result| result["event_id"] }
    Events::ALL.map do |event_id, event_name|
      results = medals_by_event.fetch(event_id, []).first(10).map do |result|
        [result["total"], result["person_link"], result["gold_medals"], result["silver_medals"], result["bronze_medals"]]
      end
      [event_name, results]
    end
  end
end
