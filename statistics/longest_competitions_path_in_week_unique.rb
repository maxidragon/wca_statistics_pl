require_relative "../core/statistic"

class LongestCompetitionsPathInWeekUnique < Statistic
  def initialize
    @title = "Longest competitions path in a single week (unique)"
    @note = "Calculated as the sum of direct distance between subsequent competitions attended within the same calendar week (Monday-Sunday). Each person appears at most once."
    @table_header = { "Distance" => :right, "Person" => :left, "Start date" => :left, "End date" => :left, "List" => :left }
  end

  def query
    <<-SQL
      SELECT
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link,
        DATE_ADD(competition.start_date, INTERVAL(-WEEKDAY(competition.start_date)) DAY) week_start_date,
        DATE_ADD(competition.start_date, INTERVAL(6-WEEKDAY(competition.start_date)) DAY) week_end_date,
        RADIANS(latitude / 1000000) latitude_radians,
        RADIANS(longitude / 1000000) longitude_radians,
        CONCAT('[', competition.cell_name, '](https://www.worldcubeassociation.org/competitions/', competition.id, ')') competition_link
      FROM (
        SELECT DISTINCT person_id, competition_id
        FROM results
      ) AS people_with_competitions
      JOIN persons person ON person.wca_id = person_id AND sub_id = 1 AND person.country_id = 'Poland'
      JOIN competitions competition ON competition.id = competition_id
      WHERE competition.country_id
        NOT IN ('XA', 'XE', 'XF', 'XM', 'XN', 'XO', 'XS', 'XW')
      ORDER BY person_link, week_start_date, competition.start_date, competition.end_date
    SQL
  end

  def transform(query_results)
    query_results
      .group_by { |r| r["person_link"] }
      .filter_map do |person_link, results|
        best = results
          .group_by { |r| [r["week_start_date"], r["week_end_date"]] }
          .filter_map do |week_key, week_results|
            next if week_results.length < 2

            distance = week_results
              .map { |r| [r["latitude_radians"], r["longitude_radians"]] }
              .each_cons(2)
              .map { |prev, curr| haversine_km(*prev, *curr) }
              .sum

            competition_links = week_results.map { |r| r["competition_link"] }.join(", ")

            [distance, week_key[0], week_key[1], competition_links]
          end
          .max_by { |distance, *| distance }

        next if best.nil?

        distance, week_start_date, week_end_date, competition_links = best
        date_format = "%e&nbsp;%b&nbsp;%Y"
        [distance.round, person_link, week_start_date.strftime(date_format), week_end_date.strftime(date_format), competition_links]
      end
      .sort_by! { |distance, *| -distance }
      .first(100)
      .map! do |distance, person_link, week_start, week_end, competition_links|
        [distance.to_s.gsub(/(\d)(?=\d{3}+$)/, '\1 ') + " km", person_link, week_start, week_end, competition_links]
      end
  end

  private

  # See http://www.movable-type.co.uk/scripts/latlong.html
  def haversine_km(lat1, lon1, lat2, lon2) # All in radians
    r = 6371 # km
    d_lat = lat2 - lat1
    d_lon = lon2 - lon1
    a = Math.sin(d_lat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(d_lon / 2) ** 2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    r * c
  end
end
