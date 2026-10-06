require_relative "../core/grouped_statistic"

class MostAttendedCompetitionsInSeries < GroupedStatistic
  # A competition belongs to a series when its id or name contains any of the
  # patterns (case-insensitive substring match).
  SERIES = {
    "BrizZon" => ["brizzon"],
    "Gdańska Liga Speedcubingu" => ["gls", "gdanskaliga"],
    "Lubelska Liga Speedcubingu" => ["lls", "lubelskaliga"],
    "Dragon Cubing" => ["dragoncubing"],
    "Sądecka Liga Speedcubingu" => ["sls"],
    "Warszawska Liga Speedcuberów" => ["wls"],
    "Krakowska Liga Speedcubingu" => ["kls"],
    "Cube Factory" => ["cubefactory", "cfgoes", "cfgs", "cfsideways", "cfclausrace"],
    "Cube Factory League" => ["cfl", "cubefactoryleague"],
    "Szansa Cubing Open" => ["szansa"],
    "Silesian Minx Fest" => ["silesianminxfest"],
    "Cubing Mine" => ["cubingmine"],
  }
  # A competition matching any of these patterns is left out of the series,
  # even when it matches one of the series' patterns.
  SERIES_EXCLUSIONS = {
    "Cube Factory" => ["cfl", "cubefactoryleague"],
  }
  # Only competitions starting on or after this date count towards the series.
  SERIES_START_DATES = {
    # Earlier SLS competitions belong to the unrelated Śląska Liga Speedcubingu.
    "Sądecka Liga Speedcubingu" => "2023-01-01",
  }
  TOP_POSITIONS = 20

  def initialize
    @title = "Most attended competitions in a series"
    @note = "Only Polish competitions with posted results are included. Up to the top #{TOP_POSITIONS} positions are listed for each series, so ties may add more rows."
    @table_header = { "Position" => :right, "Person" => :left, "Competitions" => :right }
  end

  def query
    series_competitions = SERIES.each_with_index.map do |(series_name, patterns), index|
      exclusions = SERIES_EXCLUSIONS.fetch(series_name, [])
      start_date = SERIES_START_DATES[series_name]
      <<-SQL
        SELECT #{index} AS series_index, '#{Mysql2::Client.escape(series_name)}' AS series_name, c.id AS competition_id
        FROM competitions c
        WHERE c.country_id = 'Poland'
          AND c.results_posted_at IS NOT NULL
          AND (#{matches_any(patterns)})
          #{"AND NOT (#{matches_any(exclusions)})" unless exclusions.empty?}
          #{"AND c.start_date >= '#{Mysql2::Client.escape(start_date)}'" if start_date}
      SQL
    end

    <<-SQL
      WITH series_competitions AS (
        #{series_competitions.join("UNION ALL\n")}
      ),
      series_totals AS (
        SELECT series_index, COUNT(*) AS total_competitions
        FROM series_competitions
        GROUP BY series_index
      ),
      ranked AS (
        SELECT
          sc.series_index,
          sc.series_name,
          r.person_id,
          COUNT(DISTINCT r.competition_id) AS competitions_count,
          RANK() OVER (PARTITION BY sc.series_index ORDER BY COUNT(DISTINCT r.competition_id) DESC) AS position
        FROM series_competitions sc
        JOIN results r ON r.competition_id = sc.competition_id
        GROUP BY sc.series_index, sc.series_name, r.person_id
      )
      SELECT
        ranked.series_name,
        series_totals.total_competitions,
        ranked.position,
        CONCAT('[', p.name, '](https://www.worldcubeassociation.org/persons/', p.wca_id, ')') AS person_link,
        ranked.competitions_count
      FROM ranked
      JOIN series_totals ON series_totals.series_index = ranked.series_index
      JOIN persons p ON p.wca_id = ranked.person_id AND p.sub_id = 1
      WHERE ranked.position <= #{TOP_POSITIONS}
      ORDER BY ranked.series_index, ranked.position, p.name
    SQL
  end

  def transform(query_results)
    query_results
      .group_by { |row| row["series_name"] }
      .map do |series_name, rows|
        header = "#{series_name}\n_Total competitions: #{rows.first["total_competitions"]}_"
        person_rows = rows.map { |row| [row["position"], row["person_link"], row["competitions_count"]] }
        [header, person_rows]
      end
  end

  private

  def matches_any(patterns)
    patterns.map do |pattern|
      like = "'%#{like_escape(pattern.downcase)}%'"
      "LOWER(c.id) LIKE #{like} OR LOWER(c.name) LIKE #{like}"
    end.join(" OR ")
  end

  # Treat the pattern as a literal substring, not a LIKE expression.
  def like_escape(pattern)
    Mysql2::Client.escape(pattern.gsub(/[\\%_]/) { |char| "\\#{char}" })
  end
end
