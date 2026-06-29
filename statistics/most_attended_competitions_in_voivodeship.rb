require_relative "../core/grouped_statistic"
require_relative "../core/voivodeships"

class MostAttendedCompetitionsInVoivodeship < GroupedStatistic
  include Voivodeships

  def initialize
    @title = "Competitions per voivodeship"
    @note = "Voivodeships are inferred from competition coordinates (approximate bounding box). "
    @table_header = { "Person" => :left, "Competitions" => :right }
  end

  def query
    <<-SQL
      SELECT
        p.name,
        p.wca_id,
        c.id AS competition_id,
        c.latitude / 1000000.0 AS lat,
        c.longitude / 1000000.0 AS lon
      FROM results r
      JOIN persons p ON p.wca_id = r.person_id AND p.sub_id = 1 AND p.country_id = 'Poland'
      JOIN competitions c ON c.id = r.competition_id
      WHERE c.country_id = 'Poland'
        AND c.results_posted_at IS NOT NULL
        AND c.cancelled_at IS NULL
        AND c.latitude IS NOT NULL
        AND c.longitude IS NOT NULL
      GROUP BY p.wca_id, c.id
    SQL
  end

  def transform(results)
    comp_ids_per_voiv = Hash.new { |h, k| h[k] = Set.new }
    person_count_per_voiv = Hash.new { |h, k| h[k] = Hash.new(0) }
    person_links = {}

    results.each do |row|
      voiv = voivodeship_for(row["lat"], row["lon"])
      next unless voiv

      wca_id = row["wca_id"]
      person_links[wca_id] ||= "[#{row["name"]}](https://www.worldcubeassociation.org/persons/#{wca_id})"
      comp_ids_per_voiv[voiv] << row["competition_id"]
      person_count_per_voiv[voiv][wca_id] += 1
    end

    comp_ids_per_voiv
      .sort_by { |_, ids| -ids.size }
      .map do |voiv, ids|
        person_rows = person_count_per_voiv[voiv]
          .sort_by { |_, count| -count }
          .first(30)
          .map { |wca_id, count| [person_links[wca_id], count] }

        header = "#{voivodeship_display_name(voiv)}\n_Total competitions: #{ids.size}_"
        [header, person_rows]
      end
  end
end
