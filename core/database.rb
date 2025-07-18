require 'bundler/setup'
require 'yaml'
require 'mysql2'

module Database
  DATABASE_CONFIG_PATH = File.expand_path("../database.yml", __dir__)
  DATABASE_CONFIG = YAML.load_file(DATABASE_CONFIG_PATH)
  DATABASE_CONFIG["init_command"] = "SET SESSION group_concat_max_len=4096;"
  REQUIRED_TABLES = %w(
    championships
    competitions
    competition_delegates
    competition_organizers
    continents
    countries
    events
    formats
    persons
    preferred_formats
    ranks_single
    ranks_average
    results
    round_types
    users
    schedule_activities
    venue_rooms
    competition_venues
    bookmarked_competitions
    registrations
  )
  INDICES = [
    "CREATE INDEX index_Results_on_competitionId_personId ON results (competition_id, person_id);",
  ]

  def self.client
    Mysql2::Client.new(DATABASE_CONFIG)
  end

  def self.metadata
    self.client
      .query("SELECT * FROM wca_statistics_metadata")
      .map { |row| [row["field"], row["value"]] }
      .to_h
  end
end
