require_relative "../core/statistic"

class LongestStreakOfCompetitionsInOwnCountry < Statistic
  def initialize
    @title = "Longest streak of competitions in Poland"
    @note = "The streak ends whenever the person doesn't participate in a competition in Poland."
    @table_header = { "Competitions" => :right, "Person" => :left, "Started at" => :left, "Missed" => :left }
  end

  def query
    <<-SQL
      SELECT
        CONCAT('[', person.name, '](https://www.worldcubeassociation.org/persons/', person.wca_id, ')') person_link,
        CONCAT('[', competition.cellName, '](https://www.worldcubeassociation.org/competitions/', competition.id, ')') competition_link
      FROM (
        SELECT DISTINCT personId, competitionId
        FROM Results
      ) AS people_with_competitions
      JOIN Persons person ON person.wca_id = personId AND person.subId = 1 AND person.countryId = 'Poland'
      JOIN Competitions competition ON competition.id = competitionId
      JOIN Countries country ON country.id = competition.countryId
      WHERE competition.countryId = person.countryId
      ORDER BY competition.start_date
    SQL
  end

  def transform(query_results)
    query_results
      .group_by { |result| result["country"] }
      .flat_map do |country, results|
        longest_streak_by_person = Hash.new { |hash, key| hash[key] = { count: 0 } }
        current_streak_by_person = {}
        results.group_by { |result| result["competition_link"] }.each do |competition_link, results|
          people = results.map! do |result|
            result["person_link"].tap do |person|
              current_streak_by_person[person] ||= { count: 0, first_competition: competition_link, country: country }
            end
          end
          current_streak_by_person.each do |person, current_streak|
            if people.include?(person)
              current_streak[:count] += 1
              longest_streak_by_person[person] = [longest_streak_by_person[person], current_streak].max_by { |streak| streak[:count] }
            elsif current_streak
              current_streak[:last_competition] = competition_link
              current_streak_by_person[person] = nil
            end
          end
        end
        longest_streak_by_person.to_a
      end
      .sort_by! { |person_link, longest_streak| -longest_streak[:count] }
      .map! do |person_link, longest_streak|
        [longest_streak[:count], person_link, longest_streak[:first_competition], longest_streak[:last_competition]]
      end
      .first(100)
  end
end
