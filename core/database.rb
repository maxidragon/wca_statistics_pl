require 'bundler/setup'
require 'yaml'
require 'mysql2'

module Database
  DATABASE_CONFIG_PATH = File.expand_path("../database.yml", __dir__)
  DATABASE_CONFIG = YAML.load_file(DATABASE_CONFIG_PATH)
  DATABASE_CONFIG["init_command"] = "SET SESSION group_concat_max_len=4096;"
  DEV_TABLES = %w(
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
    results
    result_attempts
    round_types
    users
    schedule_activities
    venue_rooms
    competition_venues
    bookmarked_competitions
    registrations
    competition_events
  )
  RESULTS_TABLES = %w(
    ranks_single
    ranks_average
  )
  REQUIRED_TABLES = DEV_TABLES + RESULTS_TABLES
  INDICES = [
    "CREATE INDEX index_results_on_competitionId_personId ON results (competition_id, person_id);",
    "CREATE INDEX index_results_on_person_id ON results (person_id);",
    "CREATE INDEX index_result_attempts_on_result_id ON result_attempts (result_id);",
    "CREATE INDEX index_results_on_event_id ON results (event_id);",
    "CREATE INDEX index_ranks_single_on_person_id ON ranks_single (person_id);",
    "CREATE INDEX index_ranks_average_on_person_id ON ranks_average (person_id);",
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
