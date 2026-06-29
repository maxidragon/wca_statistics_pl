require_relative "../core/statistic"
require_relative "../core/voivodeships"

class CompetedInMostVoivodeships < Statistic
  include Voivodeships

  def initialize
    @title = "Competed in most voivodeships in Poland"
    @note = "Voivodeships are inferred from competition coordinates. Approximate bounding box classification."
    @table_header = {
      "Person" => :left,
      "Completed" => :right,
      "Missed" => :right,
      "Missed Voivodeships" => :left,
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
    person_competitions = Hash.new { |h, k| h[k] = { name: "", voivodeships: Set.new, history: [] } }

    sorted_results = results.sort_by { |r| [r["wca_id"], r["end_date"]] }

    sorted_results.each do |r|
      name = r["name"]
      wca_id = r["wca_id"]
      lat = r["lat"]
      lon = r["lon"]
      competition_id = r["competition_id"]
      competition_name = r["competition_name"]
      end_date = r["end_date"]
      voiv = voivodeship_for(lat, lon)
      next unless voiv

      unless person_competitions[wca_id][:voivodeships].include?(voiv)
        person_competitions[wca_id][:history] << {
          voiv: voiv,
          competition_id: competition_id,
          competition_name: competition_name,
          end_date: end_date
        }
      end

      person_competitions[wca_id][:name] = name
      person_competitions[wca_id][:voivodeships] << voiv
    end

    person_competitions.map do |wca_id, data|
      completed = data[:voivodeships].to_a.sort
      missed = ALL - completed
      completion_info = nil

      if missed.empty? && data[:history].any?
        last = data[:history].max_by { |h| h[:end_date] }
        completion_info = "[#{last[:competition_name]}](https://www.worldcubeassociation.org/competitions/#{last[:competition_id]})"
      end

      [
        "[#{data[:name]}](https://www.worldcubeassociation.org/persons/#{wca_id})",
        completed.size,
        missed.size,
        missed.join(", "),
        completion_info
      ]
    end.sort_by { |row| [-row[1], row[2], row[0]] }.first(100)
  end
end
