#!/usr/bin/env ruby

require_relative "../core/categories"
require_relative "../statistics/index"

# Generate statistics index.
puts "Computing statistics index."
build_path = File.expand_path("../build", __dir__)

uncategorized = STATISTICS.reject { |statistic_id, statistic_object| CATEGORIES.key?(statistic_object.category) }
unless uncategorized.empty?
  abort "Statistics with a missing or unknown category: #{uncategorized.keys.join(', ')}. Use one of: #{CATEGORIES.keys.join(', ')}."
end

statistics_by_category = STATISTICS.group_by { |statistic_id, statistic_object| statistic_object.category }

# Explicit header ids, so the links don't depend on how Jekyll slugifies "&".
anchor = ->(category) { category.to_s.tr("_", "-") }

contents = CATEGORIES
  .map { |category, name| "[#{name}](##{anchor[category]}) (#{statistics_by_category.fetch(category, []).size})" }
  .join(" · ")

sections = CATEGORIES.map do |category, name|
  list = statistics_by_category.fetch(category, [])
    .sort_by { |statistics_id, statistic_object| statistic_object.title.gsub(/\d+/) { |number| number.rjust(10, "0") } }
    .map { |statistics_id, statistic_object| "- [#{statistic_object.title}](#{statistics_id})\n" }
    .join
  "## #{name} {##{anchor[category]}}\n\n#{list}"
end

destination_path = File.join(build_path, "README.md")
File.write(destination_path, ("All statistics are computed only for competitors from Poland/Polish competitions.\n\n" + contents + "\n\n" + sections.join("\n") + "\n\n" + "This information is based on competition results owned and maintained by the World Cube Assocation, published at [https://worldcubeassociation.org](https://worldcubeassociation.org) as of #{Time.now.strftime("%B %d, %Y")}."))
puts "Index file generated at #{destination_path}"
