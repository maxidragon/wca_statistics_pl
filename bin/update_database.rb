#!/usr/bin/env ruby

require 'tmpdir'
require 'fileutils'
require 'time'
require_relative "helpers"
require_relative "../core/database"

def parse_sql_dump(filename, required_tables)
  table_sqls = {}

  File.open(filename, "r") do |file|
    lines = []
    header = nil
    current_table_name = nil

    # The export comes from MariaDB and the first line is
    #
    #   /*!999999\- enable the sandbox mode */
    #
    # MySQL does not recognise this command, so we always skip this
    # line. See https://mariadb.org/mariadb-dump-file-compatibility-change
    file.readline

    until file.eof? do
      line = file.readline

      table_begin_match = line.match(/-- Table structure for table `(.*?)`/)

      if table_begin_match
        table_name = table_begin_match[1]

        if header.nil?
          header = lines.join("\n")
        elsif current_table_name
          table_sqls[current_table_name] = header + "\n" + lines.join("\n")
          current_table_name = nil
        end

        current_table_name = required_tables.include?(table_name) ? table_name : nil
        lines = []
      end

      # Only accumulate lines for the header section or a required table
      lines.push(line) if header.nil? || current_table_name
    end

    # Don't forget the last table if it was one we care about
    if current_table_name
      table_sqls[current_table_name] = header + "\n" + lines.join("\n")
    end
  end

  table_sqls
end

Dir.mktmpdir do |tmp_directory|
  FileUtils.cd tmp_directory do
    dev_export_url = "https://www.worldcubeassociation.org/wst/wca-developer-database-dump.zip"
    dev_zip_filename = "wca-developer-database-dump.zip"
    dev_filename = "wca-developer-database-dump.sql"

    results_export_url = "https://www.worldcubeassociation.org/export/results/v2/sql"
    results_zip_filename = "WCA_export.sql.zip"
    results_filename = "WCA_export.sql"

    config = Database::DATABASE_CONFIG
    mysql_with_credentials = "mysql --user=#{config["username"]} --password=#{config["password"]}"
    filter_out_mysql_warning = '2>&1 | grep -v "[Warning] Using a password on the command line interface can be insecure."'

    # Download and unzip both exports in parallel — each thread pipelines its own download+unzip
    Helpers.timed_task("Downloading and unzipping dev and results exports in parallel") do
      dev_thread = Thread.new do
        `wget --quiet #{dev_export_url}`
        `unzip #{dev_zip_filename}`
      end
      results_thread = Thread.new do
        `wget --quiet #{results_export_url} -O #{results_zip_filename}`
        `unzip #{results_zip_filename}`
      end
      dev_thread.join
      results_thread.join
    end

    Helpers.timed_task("Importing tables into #{config["database"]}") do
      `#{mysql_with_credentials} -e "DROP DATABASE IF EXISTS #{config["database"]}" #{filter_out_mysql_warning}`
      `#{mysql_with_credentials} -e "CREATE DATABASE #{config["database"]}" #{filter_out_mysql_warning}`

      # Parse dev export for dev-only tables
      table_sqls = parse_sql_dump(dev_filename, Database::DEV_TABLES)

      # Parse results export for results-only tables (ranks)
      table_sqls.merge!(parse_sql_dump(results_filename, Database::RESULTS_TABLES))

      # Stream all tables into a single persistent mysql process — avoids building
      # a combined SQL string in Ruby memory (which would double peak usage).
      mysql_cmd = "#{mysql_with_credentials} #{config["database"]} #{filter_out_mysql_warning}"
      IO.popen(mysql_cmd, "w") do |mysql_io|
        mysql_io.puts "SET FOREIGN_KEY_CHECKS=0;"

        Database::REQUIRED_TABLES.each do |table_name|
          puts "  - Importing table #{table_name}"
          table_sql = table_sqls[table_name]
          next unless table_sql

          # Get rid of indexes within the table definition in favour of index creations after all the INSERT statements.
          index_creations = ""
          table_sql.gsub!(/,\s*KEY (.\\w+.) (\([^)]*\))/m) do
            index_creations += "CREATE INDEX #{$1} ON #{table_name} #{$2};\n"
            ""
          end
          table_sql += index_creations

          # Custom indices — only apply to the table they target
          table_specific_indices = Database::INDICES.select { |idx| idx.match?(/ON\s+#{Regexp.escape(table_name)}[\s(]/i) }
          table_sql += table_specific_indices.join("\n") + "\n" unless table_specific_indices.empty?

          mysql_io.write(table_sql)
        end
      end
    end

    # Store the export timestamp
    export_timestamp = File.mtime(dev_filename)
    store_metadata_sql = "CREATE TABLE wca_statistics_metadata (field varchar(255), value varchar(255)); INSERT INTO wca_statistics_metadata (field, value) VALUES ('export_timestamp', '#{export_timestamp.iso8601}')"
    `#{mysql_with_credentials} #{config["database"]} -e "#{store_metadata_sql}" #{filter_out_mysql_warning}`
  end
end
