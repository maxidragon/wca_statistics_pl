require_relative "../core/statistic"

class AverageFeePerYear < Statistic
  def initialize
    @title = "Average base registration fee per year"
    @note = "Only competitions with a PLN base fee are included."
    @table_header = { "Year" => :left, "Avg Fee" => :right, "Competitions" => :right }
  end

  def query
    <<-SQL
      SELECT
        YEAR(start_date) AS year,
        ROUND(AVG(base_entry_fee_lowest_denomination) / 100.0, 2) AS avg_fee,
        COUNT(*) AS competition_count
      FROM competitions
      WHERE country_id = 'Poland'
        AND currency_code = 'PLN'
        AND base_entry_fee_lowest_denomination IS NOT NULL
        AND results_posted_at IS NOT NULL
        AND cancelled_at IS NULL
      GROUP BY year
      ORDER BY year ASC
    SQL
  end

  def transform(query_results)
    query_results.map do |result|
      ["%.2f PLN" % result["avg_fee"], result["competition_count"]]
        .then { |fee, count| [result["year"], fee, count] }
    end
  end
end
