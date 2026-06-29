require_relative "../core/statistic"
require_relative "../core/voivodeships"

class LongestStreakOfAllCompetitionsInSameVoivodeship < Statistic
  include Voivodeships

  def initialize
    @title = "Longest streak of all competitions in a voivodeship"
    @note = "The streak ends whenever the person misses a competition in that voivodeship. " \
            "Voivodeships are inferred from competition coordinates (approximate bounding box)."
    @table_header = { "Competitions" => :right, "Person" => :left, "Voivodeship" => :left, "Started at" => :left, "Missed" => :left }
  end

  def query
    <<-SQL
      SELECT
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') AS person_link,
        c.id AS competition_id,
        CONCAT('[', c.cell_name, '](https://www.worldcubeassociation.org/competitions/', c.id, ')') AS competition_link,
        c.start_date,
        c.latitude / 1000000.0 AS lat,
        c.longitude / 1000000.0 AS lon
      FROM (
        SELECT DISTINCT person_id, competition_id
        FROM results
      ) AS people_with_competitions
      JOIN persons person ON person.wca_id = person_id AND person.sub_id = 1 AND person.country_id = 'Poland'
      JOIN competitions c ON c.id = competition_id
      WHERE c.country_id = 'Poland'
        AND c.results_posted_at IS NOT NULL
        AND c.cancelled_at IS NULL
        AND c.latitude IS NOT NULL
        AND c.longitude IS NOT NULL
      ORDER BY c.start_date
    SQL
  end

  def transform(results)
    comp_info = {}
    comp_attendees = Hash.new { |h, k| h[k] = Set.new }

    results.each do |row|
      comp_id = row["competition_id"]
      comp_info[comp_id] ||= {
        voiv: voivodeship_for(row["lat"], row["lon"]),
        competition_link: row["competition_link"],
        start_date: row["start_date"],
      }
      comp_attendees[comp_id] << row["person_link"]
    end

    comps_by_voiv = Hash.new { |h, k| h[k] = [] }
    comp_info.each do |comp_id, info|
      next unless info[:voiv]
      comps_by_voiv[info[:voiv]] << { id: comp_id, link: info[:competition_link], start_date: info[:start_date] }
    end
    comps_by_voiv.each_value { |comps| comps.sort_by! { |c| c[:start_date] } }

    all_streaks = []

    comps_by_voiv.each do |voiv, comps|
      longest_streak_by_person = Hash.new { |h, k| h[k] = { count: 0 } }
      current_streak_by_person = {}

      comps.each do |comp|
        competition_link = comp[:link]
        attendees = comp_attendees[comp[:id]]

        attendees.each do |person|
          current_streak_by_person[person] ||= { count: 0, first_competition: competition_link }
        end

        current_streak_by_person.each do |person, current_streak|
          if attendees.include?(person)
            current_streak[:count] += 1
            longest_streak_by_person[person] = [longest_streak_by_person[person], current_streak].max_by { |s| s[:count] }
          elsif current_streak
            current_streak[:last_competition] = competition_link
            current_streak_by_person[person] = nil
          end
        end
      end

      longest_streak_by_person.each do |person, streak|
        next if streak[:count] == 0
        all_streaks << [streak[:count], person, voivodeship_display_name(voiv), streak[:first_competition], streak[:last_competition]]
      end
    end

    all_streaks.sort_by { |row| -row[0] }.first(100)
  end
end
