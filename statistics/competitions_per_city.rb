require_relative "../core/grouped_statistic"

class CompetitionsPerCity < GroupedStatistic
  def initialize
    @title = "Competitions per city"
    @note = "Only Polish persons and Polish competitions with posted results are included."
    @table_header = { "Person" => :left, "Competitions" => :right }
  end

  def query
    <<-SQL
      SELECT
        p.name,
        p.wca_id,
        c.id AS competition_id,
        c.city_name
      FROM results r
      JOIN persons p ON p.wca_id = r.person_id AND p.sub_id = 1 AND p.country_id = 'Poland'
      JOIN competitions c ON c.id = r.competition_id
      WHERE c.country_id = 'Poland'
        AND c.results_posted_at IS NOT NULL
        AND c.cancelled_at IS NULL
      GROUP BY p.wca_id, c.id
    SQL
  end

  def transform(results)
    comp_ids_per_city = Hash.new { |h, k| h[k] = Set.new }
    person_count_per_city = Hash.new { |h, k| h[k] = Hash.new(0) }
    person_links = {}

    results.each do |row|
      city = row["city_name"]
      wca_id = row["wca_id"]
      person_links[wca_id] ||= "[#{row["name"]}](https://www.worldcubeassociation.org/persons/#{wca_id})"
      comp_ids_per_city[city] << row["competition_id"]
      person_count_per_city[city][wca_id] += 1
    end

    comp_ids_per_city
      .sort_by { |_, ids| -ids.size }
      .map do |city, ids|
        person_rows = person_count_per_city[city]
          .sort_by { |_, count| -count }
          .first(30)
          .map { |wca_id, count| [person_links[wca_id], count] }

        header = "#{city}\n_Total competitions: #{ids.size}_"
        [header, person_rows]
      end
  end
end
