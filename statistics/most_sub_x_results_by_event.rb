require_relative "../core/statistic"
require_relative "../core/events"
require_relative "../core/solve_time"

class MostSubXResultsByEvent < Statistic
  THRESHOLDS = {
    "333"    => { field: :average, values: [1000, 900, 800, 700, 600, 500],        labels: %w[sub-10 sub-9 sub-8 sub-7 sub-6 sub-5] },
    "222"    => { field: :average, values: [200, 150, 100],                         labels: ["sub-2", "sub-1.5", "sub-1"] },
    "444"    => { field: :average, values: [3000, 2500, 2000],                      labels: %w[sub-30 sub-25 sub-20] },
    "555"    => { field: :average, values: [6000, 5000, 4000],                      labels: ["sub-1:00", "sub-50", "sub-40"] },
    "666"    => { field: :average, values: [15000, 12000, 10500, 9000],             labels: ["sub-2:30", "sub-2:00", "sub-1:45", "sub-1:30"] },
    "777"    => { field: :average, values: [24000, 21000, 18000, 15000, 13500, 12000], labels: ["sub-4:00", "sub-3:30", "sub-3:00", "sub-2:30", "sub-2:15", "sub-2:00"] },
    "333oh"  => { field: :average, values: [1500, 1200, 1000, 900, 800],            labels: %w[sub-15 sub-12 sub-10 sub-9 sub-8] },
    "minx"   => { field: :average, values: [6000, 5000, 4500, 4000, 3500, 3200, 3000], labels: ["sub-1:00", "sub-50", "sub-45", "sub-40", "sub-35", "sub-32", "sub-30"] },
    "pyram"  => { field: :average, values: [300, 200],                              labels: %w[sub-3 sub-2] },
    "skewb"  => { field: :average, values: [300, 200],                              labels: %w[sub-3 sub-2] },
    "clock"  => { field: :average, values: [500, 400, 300, 250],                    labels: ["sub-5", "sub-4", "sub-3", "sub-2.5"] },
    "sq1"    => { field: :average, values: [1200, 1000, 800, 700, 600],             labels: %w[sub-12 sub-10 sub-8 sub-7 sub-6] },
    "333fm"  => { field: :average, values: [2500, 2300, 2000],                      labels: %w[sub-25 sub-23 sub-20] },
    "333bf"  => { field: :single,  values: [6000, 4500, 3000, 2500, 2000],          labels: ["sub-1:00", "sub-45", "sub-30", "sub-25", "sub-20"] },
    "444bf"  => { field: :single,  values: [18000, 15000, 12000],                   labels: ["sub-3:00", "sub-2:30", "sub-2:00"] },
    "555bf"  => { field: :single,  values: [30000, 24000],                          labels: ["sub-5:00", "sub-4:00"] },
    "333mbf" => { field: :multi,   values: [10, 20, 30, 40, 50],                    labels: %w[10+ 20+ 30+ 40+ 50+] },
  }.freeze

  def initialize
    @title = "Most sub-X results by event"
    @note = "Counts competition averages below the threshold for speed events, singles for BLD events. For Multi-BLD, counts results with strictly more than the given number of points."
  end

  def query
    event_ids = THRESHOLDS.keys.map { |e| "'#{e}'" }.join(", ")
    <<-SQL
      SELECT
        r.event_id,
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link,
        r.average,
        r.best
      FROM results r
      JOIN persons person ON person.wca_id = r.person_id AND person.sub_id = 1 AND person.country_id = 'Poland'
      WHERE r.event_id IN (#{event_ids})
    SQL
  end

  def transform(query_results)
    by_event = query_results.group_by { |r| r["event_id"] }

    THRESHOLDS.map do |event_id, config|
      event_name = Events::ALL[event_id] || event_id
      field = config[:field]
      per_person = (by_event[event_id] || []).group_by { |r| r["person_link"] }

      sections = config[:values].zip(config[:labels]).map do |threshold, label|
        top10 = per_person
          .filter_map do |person_link, results|
            count = case field
                    when :average then results.count { |r| r["average"].to_i > 0 && r["average"].to_i < threshold }
                    when :single  then results.count { |r| r["best"].to_i > 0 && r["best"].to_i < threshold }
                    when :multi   then results.count { |r| r["best"].to_i > 0 && SolveTime.new("333mbf", :best, r["best"].to_i).points > threshold }
                    end
            next if count.zero?
            [count, person_link]
          end
          .sort_by { |count, _| -count }
          .first(10)
        [label, top10]
      end

      [event_name, sections]
    end
  end

  def markdown
    table_header = { "Count" => :right, "Person" => :left }
    text = top
    data.each do |event_name, sections|
      next unless sections.any? { |_, rows| rows.any? }
      text += "\n### #{event_name}\n"
      sections.each do |label, rows|
        next if rows.empty?
        section_title = label.sub(/^sub-/, "Sub ")
        text += "\n#### #{section_title}\n\n"
        text += markdown_table(table_header, rows)
      end
    end
    text
  end
end
