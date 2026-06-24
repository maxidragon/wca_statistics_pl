require_relative "../core/statistic"

class LongestDistanceBetweenCompetitionsOnConsecutiveDays < Statistic
  def initialize
    @title = "Longest distance between competitions on consecutive days"
    @note = "Calculated as the direct distance between two competitions with overlapping or adjacent dates. Excludes multi-location competitions."
    @table_header = { "Person" => :left, "Distance" => :right, "From" => :left, "To" => :left }
  end

  def query
    <<-SQL
      SELECT
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') AS person_link,
        competition.id AS competition_id,
        competition.name AS competition_name,
        country.name AS country_name,
        competition.start_date,
        competition.end_date,
        RADIANS(competition.latitude / 1000000) AS latitude_radians,
        RADIANS(competition.longitude / 1000000) AS longitude_radians
      FROM (
        SELECT DISTINCT person_id, competition_id
        FROM results
      ) AS people_with_competitions
      JOIN persons person ON person.wca_id = person_id AND sub_id = 1 AND person.country_id = 'Poland'
      JOIN competitions competition ON competition.id = competition_id
      JOIN countries country ON country.id = competition.country_id
      WHERE competition.country_id NOT IN ('XA', 'XE', 'XF', 'XM', 'XN', 'XO', 'XS', 'XW')
        AND competition.id NOT IN (
          SELECT competition_id
          FROM competition_venues
          GROUP BY competition_id
          HAVING COUNT(*) > 1
        )
      ORDER BY competition.start_date, competition.end_date
    SQL
  end

  def transform(query_results)
    rows = []

    query_results
      .group_by { |result| result["person_link"] }
      .each do |person_link, results|
        sorted = results.sort_by { |r| [r["start_date"], r["end_date"]] }

        sorted.each_cons(2) do |prev, curr|
          next unless curr["start_date"] <= prev["end_date"] + 1

          dist = distance_km(
            prev["latitude_radians"], prev["longitude_radians"],
            curr["latitude_radians"], curr["longitude_radians"]
          )

          rows << [
            person_link,
            dist.round,
            "[#{prev['competition_name']}](https://www.worldcubeassociation.org/competitions/#{prev['competition_id']}) (#{prev['country_name']})",
            "[#{curr['competition_name']}](https://www.worldcubeassociation.org/competitions/#{curr['competition_id']}) (#{curr['country_name']})"
          ]
        end
      end

    rows
      .sort_by! { |row| -row[1] }
      .map! do |person_link, distance, from, to|
        [person_link, distance.to_s.gsub(/(\d)(?=\d{3}+$)/, '\1 ') + " km", from, to]
      end
      .first(100)
  end

  private

  # See http://www.movable-type.co.uk/scripts/latlong.html
  def distance_km(lat1, lon1, lat2, lon2) # All in radians
    r = 6371
    d_lat = lat2 - lat1
    d_lon = lon2 - lon1
    a = Math.sin(d_lat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(d_lon / 2) ** 2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    r * c
  end
end
