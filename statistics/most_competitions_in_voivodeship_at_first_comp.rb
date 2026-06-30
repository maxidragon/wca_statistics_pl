require_relative "../core/statistic"
require_relative "../core/voivodeships"

class MostCompetitionsInVoivodeshipAtFirstComp < Statistic
  include Voivodeships

  def initialize
    @title = "Most % of competitions attended in the same voivodeship as the first competition of the competitor"
    @note = "Counts how many Polish competitions a person attended in the same voivodeship " \
            "where they had their first Polish competition. " \
            "The ratio is computed against all competitions attended, including those abroad."
    @table_header = {
      "Person" => :left,
      "First Competition" => :left,
      "Voivodeship" => :left,
      "Comps in Voivodeship" => :right,
      "Total Comps" => :right,
      "Ratio" => :right,
    }
  end

  def query
    <<-SQL
      SELECT
        p.name,
        p.wca_id,
        c.id AS competition_id,
        c.name AS competition_name,
        c.start_date,
        IF(c.country_id = 'Poland' AND c.latitude IS NOT NULL AND c.longitude IS NOT NULL,
           c.latitude / 1000000.0, NULL) AS lat,
        IF(c.country_id = 'Poland' AND c.latitude IS NOT NULL AND c.longitude IS NOT NULL,
           c.longitude / 1000000.0, NULL) AS lon
      FROM results r
      JOIN persons p ON p.wca_id = r.person_id AND p.sub_id = 1 AND p.country_id = 'Poland'
      JOIN competitions c ON c.id = r.competition_id
      WHERE c.results_posted_at IS NOT NULL
        AND c.cancelled_at IS NULL
      GROUP BY p.wca_id, c.id
    SQL
  end

  def transform(results)
    persons = {}
    results.each do |row|
      wca_id = row["wca_id"]
      persons[wca_id] ||= { name: row["name"], comps: [] }
      persons[wca_id][:comps] << {
        competition_id: row["competition_id"],
        competition_name: row["competition_name"],
        start_date: row["start_date"],
        lat: row["lat"],
        lon: row["lon"],
      }
    end

    rows = persons.filter_map do |wca_id, data|
      first_comp = data[:comps].min_by { |c| c[:start_date] }
      next unless first_comp[:lat] && first_comp[:lon]

      voiv = voivodeship_for(first_comp[:lat], first_comp[:lon])
      next unless voiv

      total = data[:comps].size
      count = data[:comps].count { |c| c[:lat] && c[:lon] && voivodeship_for(c[:lat], c[:lon]) == voiv }
      ratio = count.to_f / total

      [
        "[#{data[:name]}](https://www.worldcubeassociation.org/persons/#{wca_id})",
        "[#{first_comp[:competition_name]}](https://www.worldcubeassociation.org/competitions/#{first_comp[:competition_id]})",
        voivodeship_display_name(voiv),
        count,
        total,
        "%.1f%%" % (ratio * 100),
        ratio,
      ]
    end

    rows
      .sort_by { |row| [-row[6], -row[3], row[0]] }
      .first(100)
      .map { |row| row[0..5] }
  end
end
