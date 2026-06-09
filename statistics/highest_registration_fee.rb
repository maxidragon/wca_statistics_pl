require_relative "../core/grouped_statistic"

class HighestRegistrationFee < GroupedStatistic
  def initialize
    @title = "Highest registration fee at Polish competitions"
    @note = "Only competitions with a PLN base fee are included."
    @table_header = { "Fee" => :right, "Competition" => :left, "Date" => :left }
  end

  def query
    <<-SQL
      SELECT
        YEAR(start_date) AS year,
        CONCAT('[', cell_name, '](https://www.worldcubeassociation.org/competitions/', id, ')') AS competition_link,
        start_date,
        base_entry_fee_lowest_denomination / 100.0 AS fee_pln
      FROM competitions
      WHERE country_id = 'Poland'
        AND currency_code = 'PLN'
        AND base_entry_fee_lowest_denomination IS NOT NULL
        AND results_posted_at IS NOT NULL
        AND cancelled_at IS NULL
      ORDER BY year DESC, base_entry_fee_lowest_denomination DESC, start_date ASC
    SQL
  end

  def transform(query_results)
    query_results
      .group_by { |row| row["year"] }
      .map do |year, rows|
        comp_rows = rows.first(10).map do |row|
          ["%.2f PLN" % row["fee_pln"], row["competition_link"], row["start_date"]]
        end
        [year, comp_rows]
      end
  end
end
