require_relative "../core/statistic"
require_relative "../core/voivodeships"

class ShortestTimeToCompeteInAllVoivodeships < Statistic
  include Voivodeships

  def initialize
    @title = "Shortest time to compete in all voivodeships in Poland"
    @note = "Voivodeships are inferred from competition coordinates. Approximate bounding box classification."
    @table_header = {
      "Person" => :left,
      "Days" => :right,
      "Completed At" => :left
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
        c.end_date,
        c.latitude / 1000000.0 AS lat,
        c.longitude / 1000000.0 AS lon
      FROM results r
      JOIN persons p ON p.wca_id = r.person_id AND p.sub_id = 1 AND p.country_id = 'Poland'
      JOIN competitions c ON c.id = r.competition_id
      WHERE c.country_id = 'Poland'
      GROUP BY p.wca_id, c.id
    SQL
  end

  def transform(results)
    person_competitions = Hash.new { |h, k| h[k] = { name: "", voivodeships: Set.new, history: [], first_start_date: nil } }

    sorted_results = results.sort_by { |r| [r["wca_id"], r["end_date"]] }

    sorted_results.each do |r|
      name = r["name"]
      wca_id = r["wca_id"]
      lat = r["lat"]
      lon = r["lon"]
      competition_id = r["competition_id"]
      competition_name = r["competition_name"]
      start_date = r["start_date"]
      end_date = r["end_date"]
      voiv = voivodeship_for(lat, lon)
      next unless voiv

      person_competitions[wca_id][:first_start_date] ||= start_date

      unless person_competitions[wca_id][:voivodeships].include?(voiv)
        person_competitions[wca_id][:history] << {
          voiv: voiv,
          competition_id: competition_id,
          competition_name: competition_name,
          start_date: start_date,
          end_date: end_date
        }
      end

      person_competitions[wca_id][:name] = name
      person_competitions[wca_id][:voivodeships] << voiv
    end

    person_competitions.filter_map do |wca_id, data|
      completed = data[:voivodeships].to_a.sort
      next unless (ALL - completed).empty? && data[:history].any?

      last = data[:history].max_by { |h| h[:end_date] }
      completion_info = "[#{last[:competition_name]}](https://www.worldcubeassociation.org/competitions/#{last[:competition_id]})"
      days = (last[:start_date] - data[:first_start_date]).to_i + 1

      [
        "[#{data[:name]}](https://www.worldcubeassociation.org/persons/#{wca_id})",
        days,
        completion_info
      ]
    end.sort_by { |row| [row[1], row[0]] }
  end
end
