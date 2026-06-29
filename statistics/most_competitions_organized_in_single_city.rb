require_relative "../core/statistic"

class MostCompetitionsOrganizedInSingleCity < Statistic
  def initialize
    @title = "Most competitions organized in a single city before organizing elsewhere"
    @note = "Counts how many competitions a Polish organizer organized in their first city " \
            "before organizing in a different city for the first time. " \
            "Only Polish competitions are included."
    @table_header = {
      "Person" => :left,
      "City" => :left,
      "Competitions" => :right,
      "Ended at" => :left,
    }
  end

  def query
    <<-SQL
      SELECT
        co.organizer_id,
        CASE
          WHEN u.wca_id IS NOT NULL THEN CONCAT('[', u.name, '](https://www.worldcubeassociation.org/persons/', u.wca_id, ')')
          ELSE u.name
        END AS person_link,
        c.id AS competition_id,
        c.name AS competition_name,
        c.city_name,
        c.start_date
      FROM competition_organizers co
      JOIN competitions c ON c.id = co.competition_id
      JOIN users u ON u.id = co.organizer_id AND u.country_iso2 = 'PL'
      WHERE c.country_id = 'Poland'
        AND c.show_at_all = 1
        AND c.cancelled_at IS NULL
        AND c.start_date < CURDATE()
      GROUP BY co.organizer_id, c.id
    SQL
  end

  def transform(results)
    organizers = {}
    results.each do |row|
      id = row["organizer_id"]
      organizers[id] ||= { person_link: row["person_link"], comps: [] }
      organizers[id][:comps] << {
        competition_id: row["competition_id"],
        competition_name: row["competition_name"],
        city: row["city_name"],
        start_date: row["start_date"],
      }
    end

    rows = organizers.filter_map do |_, data|
      comps = data[:comps].sort_by { |c| c[:start_date] }
      first_city = comps.first[:city]

      breaking_comp = comps.find { |c| c[:city] != first_city }

      streak = if breaking_comp
        comps.count { |c| c[:city] == first_city && c[:start_date] <= breaking_comp[:start_date] }
      else
        comps.count { |c| c[:city] == first_city }
      end

      broke_at = if breaking_comp
        "[#{breaking_comp[:competition_name]}](https://www.worldcubeassociation.org/competitions/#{breaking_comp[:competition_id]})"
      else
        nil
      end

      [
        data[:person_link],
        first_city,
        streak,
        broke_at,
      ]
    end

    rows.sort_by { |row| -row[2] }.first(100)
  end
end
