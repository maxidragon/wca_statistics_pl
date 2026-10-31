require_relative "abstract/places_with_most_competitions_by_year"
require_relative "../core/voivodeships"

class VoivodeshipsWithMostCompetitionsByYear < PlacesWithMostCompetitionsByYear
  include Voivodeships

  def initialize
    super(place: "Voivodeship", places: "Voivodeships", note: "Voivodeship is inferred from competition coordinates.")
  end

  def place_for(row)
    lat, lon = row["lat"].to_f, row["lon"].to_f
    voivodeship_display_name(voivodeship_for(lat, lon) || nearest_voivodeship_for(lat, lon))
  end
end
