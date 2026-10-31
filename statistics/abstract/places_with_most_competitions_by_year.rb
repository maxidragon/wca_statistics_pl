require_relative "../../core/grouped_statistic"

# For each year, lists the places that hosted the most Polish competitions.
# Subclasses define what the place of a competition is.
class PlacesWithMostCompetitionsByYear < GroupedStatistic
  def initialize(place:, places:, note:)
    @title = "#{places} with the most competitions each year"
    @category = :competitions
    @note = note
    @table_header = { "Competitions" => :right, place => :left }
  end

  def query
    <<-SQL
      SELECT
        YEAR(start_date) AS year,
        city_name,
        latitude / 1000000.0 AS lat,
        longitude / 1000000.0 AS lon
      FROM competitions
      WHERE country_id = 'Poland'
        AND show_at_all = 1
        AND cancelled_at IS NULL
        AND start_date < CURDATE()
      ORDER BY year DESC
    SQL
  end

  def place_for(row)
    raise "Must implement #place_for"
  end

  def transform(query_results)
    query_results
      .group_by { |row| row["year"] }
      .map do |year, rows|
        place_rows = rows
          .map { |row| place_for(row) }
          .tally
          .sort_by { |place, count| [-count, place] }
          .first(20)
          .map { |place, count| [count, place] }
        [year, place_rows]
      end
  end
end
