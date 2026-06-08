require_relative "../core/grouped_statistic"

class AverageFeePerVoivodeship < GroupedStatistic
  VOIVODESHIPS = {
    "dolnośląskie"        => [50.09, 51.74, 15.03, 17.93],
    "kujawsko-pomorskie"  => [52.58, 53.81, 17.45, 19.85],
    "lubelskie"           => [50.33, 51.64, 22.01, 24.15],
    "lubuskie"            => [51.08, 52.92, 14.12, 16.12],
    "łódzkie"             => [51.00, 52.25, 18.17, 20.28],
    "małopolskie"         => [49.33, 50.50, 19.15, 21.25],
    "mazowieckie"         => [51.40, 53.55, 19.00, 22.00],
    "opolskie"            => [50.17, 51.13, 17.33, 18.77],
    "podkarpackie"        => [49.00, 50.55, 21.28, 23.53],
    "podlaskie"           => [52.60, 54.50, 22.75, 23.85],
    "pomorskie"           => [53.60, 55.15, 16.50, 19.75],
    "śląskie"             => [49.40, 50.75, 18.00, 19.95],
    "świętokrzyskie"      => [50.30, 51.15, 19.90, 21.45],
    "warmińsko-mazurskie" => [53.50, 54.45, 19.20, 22.95],
    "wielkopolskie"       => [51.60, 53.50, 16.10, 18.90],
    "zachodniopomorskie"  => [53.05, 54.35, 14.10, 16.70],
  }.freeze

  def initialize
    @title = "Average base registration fee per voivodeship"
    @note = "Voivodeship is inferred from competition coordinates (approximate bounding box). " \
            "Only PLN competitions are included."
    @table_header = { "Voivodeship" => :left, "Avg Fee" => :right, "Competitions" => :right }
  end

  def query
    <<-SQL
      SELECT
        YEAR(start_date) AS year,
        base_entry_fee_lowest_denomination / 100.0 AS fee_pln,
        latitude / 1000000.0 AS lat,
        longitude / 1000000.0 AS lon
      FROM competitions
      WHERE country_id = 'Poland'
        AND currency_code = 'PLN'
        AND base_entry_fee_lowest_denomination IS NOT NULL
        AND results_posted_at IS NOT NULL
        AND cancelled_at IS NULL
        AND latitude IS NOT NULL
        AND longitude IS NOT NULL
    SQL
  end

  def transform(query_results)
    query_results
      .group_by { |row| row["year"] }
      .sort_by { |year, _| -year }
      .map do |year, rows|
        by_voivodeship = Hash.new { |h, k| h[k] = [] }
        rows.each do |row|
          voiv = voivodeship_for(row["lat"].to_f, row["lon"].to_f)
          by_voivodeship[voiv] << row["fee_pln"].to_f if voiv
        end

        voivodeship_rows = by_voivodeship
          .map { |voiv, fees| [display_name(voiv), fees.sum / fees.size, fees.size] }
          .sort_by { |_, avg_fee, _| -avg_fee }
          .map { |name, avg_fee, count| [name, "%.2f PLN" % avg_fee, count] }

        [year, voivodeship_rows]
      end
  end

  private

  def voivodeship_for(lat, lon)
    candidates = VOIVODESHIPS.select do |_, (lat_min, lat_max, lon_min, lon_max)|
      lat >= lat_min && lat <= lat_max && lon >= lon_min && lon <= lon_max
    end
    candidates.min_by { |_, (lat_min, lat_max, lon_min, lon_max)| (lat_max - lat_min) * (lon_max - lon_min) }&.first
  end

  def display_name(voiv)
    voiv.split('-').map { |w| w[0].upcase + w[1..] }.join('-')
  end
end
