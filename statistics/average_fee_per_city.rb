require_relative "../core/grouped_statistic"

class AverageFeePerCity < GroupedStatistic
  def initialize
    @title = "Average registration fee per city"
    @category = :competitions
    @note = "Only PLN competitions are included. Only cities with at least 2 competitions in a given year are listed."
    @table_header = { "City" => :left, "Avg Fee" => :right, "Competitions" => :right }
  end

  def query
    <<-SQL
      SELECT
        YEAR(start_date) AS year,
        city_name,
        base_entry_fee_lowest_denomination / 100.0 AS fee_pln
      FROM competitions
      WHERE country_id = 'Poland'
        AND currency_code = 'PLN'
        AND base_entry_fee_lowest_denomination IS NOT NULL
        AND results_posted_at IS NOT NULL
        AND cancelled_at IS NULL
    SQL
  end

  def transform(query_results)
    query_results
      .group_by { |row| row["year"] }
      .sort_by { |year, _| -year }
      .map do |year, rows|
        city_rows = rows
          .group_by { |row| row["city_name"] }
          .select { |_, city_comps| city_comps.size >= 2 }
          .map { |city, city_comps| [city, city_comps.sum { |row| row["fee_pln"].to_f } / city_comps.size, city_comps.size] }
          .sort_by { |city, avg_fee, _| [-avg_fee, city] }
          .map { |city, avg_fee, count| [city, "%.2f PLN" % avg_fee, count] }

        [year, city_rows]
      end
      .reject { |_, city_rows| city_rows.empty? }
  end
end
