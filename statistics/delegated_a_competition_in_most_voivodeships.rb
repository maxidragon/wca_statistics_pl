require_relative "../core/statistic"
require_relative "../core/voivodeships"

class DelegatedACompetitionInMostVoivodeships < Statistic
  include Voivodeships

  def initialize
    @title = "Delegated competitions in most voivodeships in Poland"
    @note = "Voivodeships are inferred from competition coordinates (approximate bounding box). " \
            "Only Polish delegates and Polish competitions with posted results are included."
    @table_header = {
      "Delegate" => :left,
      "Delegated" => :right,
      "Missed" => :right,
      "Missed Voivodeships" => :left,
      "Completed At" => :left,
    }
  end

  def query
    <<-SQL
      SELECT
        person.name,
        person.wca_id,
        cd.delegate_id,
        c.id AS competition_id,
        c.name AS competition_name,
        c.end_date,
        c.latitude / 1000000.0 AS lat,
        c.longitude / 1000000.0 AS lon
      FROM competition_delegates cd
      JOIN competitions c ON c.id = cd.competition_id
      JOIN users u ON u.id = cd.delegate_id
      JOIN persons person ON person.wca_id = u.wca_id AND person.sub_id = 1 AND person.country_id = 'Poland'
      WHERE c.country_id = 'Poland'
        AND c.show_at_all = 1
        AND c.cancelled_at IS NULL
        AND c.results_posted_at IS NOT NULL
      GROUP BY cd.delegate_id, c.id
    SQL
  end

  def transform(results)
    delegate_data = Hash.new { |h, k| h[k] = { name: "", voivodeships: Set.new, history: [] } }

    results.sort_by { |r| [r["delegate_id"], r["end_date"]] }.each do |r|
      delegate_id = r["delegate_id"]
      voiv = voivodeship_for(r["lat"], r["lon"])
      next unless voiv

      unless delegate_data[delegate_id][:voivodeships].include?(voiv)
        delegate_data[delegate_id][:history] << {
          voiv: voiv,
          competition_id: r["competition_id"],
          competition_name: r["competition_name"],
          end_date: r["end_date"],
        }
      end

      delegate_data[delegate_id][:name] = r["name"]
      delegate_data[delegate_id][:wca_id] = r["wca_id"]
      delegate_data[delegate_id][:voivodeships] << voiv
    end

    delegate_data.map do |_, data|
      delegated = data[:voivodeships].to_a.sort
      missed = ALL - delegated
      completion_info = nil

      if missed.empty? && data[:history].any?
        last = data[:history].max_by { |h| h[:end_date] }
        completion_info = "[#{last[:competition_name]}](https://www.worldcubeassociation.org/competitions/#{last[:competition_id]})"
      end

      [
        "[#{data[:name]}](https://www.worldcubeassociation.org/persons/#{data[:wca_id]})",
        delegated.size,
        missed.size,
        missed.join(", "),
        completion_info,
      ]
    end.sort_by { |row| [-row[1], row[2], row[0]] }.first(100)
  end
end
