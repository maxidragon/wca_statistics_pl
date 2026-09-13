require_relative "../core/grouped_statistic"

class HighestPercentageOfDelegatesPerCompetitor < GroupedStatistic
  VARIANTS = {
    "listed" => "Listed delegates only",
    "unlisted" => "Unlisted delegates only",
    "listed_and_unlisted" => "Listed and unlisted delegates"
  }.freeze

  def initialize
    @title = "Highest percentage of delegates per competitor"
    @note = "Only Polish competitions with posted results are included. Listed delegates are taken from the competition's delegate list and do not have to compete. An unlisted delegate is a competitor who was not listed and whose RolesMetadataDelegateRegions role was active during at least one day of the competition. Because some historical role dates were not backfilled, a role starting on 1 August 2004 is treated as starting at the delegate's earliest listed competition instead."
    @table_header = {
      "%" => :right,
      "Competition" => :left,
      "Delegates" => :right,
      "Competitors" => :right,
      "Delegate list" => :left
    }
    @combined_table_header = {
      "%" => :right,
      "Competition" => :left,
      "Delegates" => :right,
      "Listed" => :right,
      "Unlisted" => :right,
      "Competitors" => :right,
      "Listed delegate list" => :left,
      "Unlisted delegate list" => :left
    }
  end

  def query
    <<-SQL
      WITH competition_people AS (
        SELECT
          result.competition_id,
          result.person_id
        FROM results result
        JOIN competitions competition ON competition.id = result.competition_id
        WHERE competition.country_id = 'Poland'
          AND competition.cancelled_at IS NULL
          AND competition.results_posted_at IS NOT NULL
        GROUP BY result.competition_id, result.person_id
      ),
      competition_competitors AS (
        SELECT competition_id, COUNT(*) competitor_count
        FROM competition_people
        GROUP BY competition_id
      ),
      listed_delegates AS (
        SELECT competition_delegates.competition_id, competition_delegates.delegate_id
        FROM competition_delegates
        JOIN competition_competitors ON competition_competitors.competition_id = competition_delegates.competition_id
      ),
      first_listed_competitions AS (
        SELECT
          competition_delegates.delegate_id,
          MIN(competition.start_date) first_competition_date
        FROM competition_delegates
        JOIN competitions competition ON competition.id = competition_delegates.competition_id
        GROUP BY competition_delegates.delegate_id
      ),
      delegate_roles AS (
        SELECT
          user_role.user_id,
          CASE
            WHEN user_role.start_date = '2004-08-01'
              THEN COALESCE(first_listed_competitions.first_competition_date, user_role.start_date)
            ELSE user_role.start_date
          END effective_start_date,
          user_role.end_date
        FROM user_roles user_role
        LEFT JOIN first_listed_competitions ON first_listed_competitions.delegate_id = user_role.user_id
        WHERE user_role.metadata_type = 'RolesMetadataDelegateRegions'
      ),
      unlisted_delegates AS (
        SELECT DISTINCT
          competition.id competition_id,
          delegate_role.user_id delegate_id
        FROM competition_people
        JOIN competitions competition ON competition.id = competition_people.competition_id
        JOIN users user ON user.wca_id = competition_people.person_id
        JOIN delegate_roles delegate_role
          ON delegate_role.user_id = user.id
          AND delegate_role.effective_start_date <= competition.end_date
          AND (delegate_role.end_date IS NULL OR delegate_role.end_date > competition.start_date)
        WHERE NOT EXISTS (
          SELECT 1
          FROM listed_delegates
          WHERE listed_delegates.competition_id = competition.id
            AND listed_delegates.delegate_id = delegate_role.user_id
        )
      ),
      variant_delegates AS (
        SELECT 'listed' variant, 'listed' delegate_type, competition_id, delegate_id FROM listed_delegates
        UNION ALL
        SELECT 'unlisted' variant, 'unlisted' delegate_type, competition_id, delegate_id FROM unlisted_delegates
        UNION ALL
        SELECT 'listed_and_unlisted' variant, 'listed' delegate_type, competition_id, delegate_id FROM listed_delegates
        UNION ALL
        SELECT 'listed_and_unlisted' variant, 'unlisted' delegate_type, competition_id, delegate_id FROM unlisted_delegates
      )
      SELECT
        variant_delegates.variant,
        variant_delegates.delegate_type,
        variant_delegates.delegate_id,
        competition.id competition_id,
        competition.start_date,
        CONCAT('[', competition.cell_name, '](https://www.worldcubeassociation.org/competitions/', competition.id, ')') competition_link,
        competition_competitors.competitor_count,
        user.name delegate_name,
        user.wca_id delegate_wca_id
      FROM variant_delegates
      JOIN competition_competitors ON competition_competitors.competition_id = variant_delegates.competition_id
      JOIN competitions competition ON competition.id = variant_delegates.competition_id
      JOIN users user ON user.id = variant_delegates.delegate_id
      ORDER BY
        FIELD(variant_delegates.variant, 'listed', 'unlisted', 'listed_and_unlisted'),
        competition.start_date,
        competition.id,
        user.name
    SQL
  end

  def transform(query_results)
    rows_by_variant = query_results.group_by { |row| row["variant"] }

    VARIANTS.map do |variant, title|
      rows = rows_by_variant
        .fetch(variant, [])
        .group_by { |row| row["competition_id"] }
        .map do |competition_id, delegate_rows|
          delegates = delegate_rows.uniq { |row| row["delegate_id"] }
          listed_delegates = delegates.select { |row| row["delegate_type"] == "listed" }
          unlisted_delegates = delegates.select { |row| row["delegate_type"] == "unlisted" }
          competitor_count = delegate_rows.first["competitor_count"].to_i
          percentage = 100.0 * delegates.length / competitor_count

          [
            percentage,
            delegate_rows.first["competition_link"],
            delegates.length,
            listed_delegates.length,
            unlisted_delegates.length,
            competitor_count,
            format_delegate_links(delegates),
            format_delegate_links(listed_delegates),
            format_delegate_links(unlisted_delegates),
            delegate_rows.first["start_date"],
            competition_id
          ]
        end
        .sort_by do |percentage, _, delegate_count, _, _, competitor_count, _, _, _, start_date, competition_id|
          [-percentage, -delegate_count, -competitor_count, start_date.to_s, competition_id]
        end
        .first(50)
        .map do |percentage, competition_link, delegate_count, listed_count, unlisted_count, competitor_count, all_delegate_links, listed_delegate_links, unlisted_delegate_links, _, _|
          if variant == "listed_and_unlisted"
            [
              format("%.2f%%", percentage),
              competition_link,
              delegate_count,
              listed_count,
              unlisted_count,
              competitor_count,
              listed_delegate_links,
              unlisted_delegate_links
            ]
          else
            [format("%.2f%%", percentage), competition_link, delegate_count, competitor_count, all_delegate_links]
          end
        end

      [title, rows]
    end
  end

  def markdown
    markdown = top
    data.each do |title, rows|
      next if rows.empty?

      header = title == VARIANTS["listed_and_unlisted"] ? @combined_table_header : @table_header
      markdown += "\n### #{title}\n\n"
      markdown += markdown_table(header, rows)
    end
    markdown
  end

  private

  def format_delegate_links(delegates)
    delegates
      .sort_by { |row| row["delegate_name"] }
      .map { |row| delegate_link(row) }
      .join(", ")
  end

  def delegate_link(row)
    return row["delegate_name"] if row["delegate_wca_id"].nil?

    "[#{row["delegate_name"]}](https://www.worldcubeassociation.org/persons/#{row["delegate_wca_id"]})"
  end
end
