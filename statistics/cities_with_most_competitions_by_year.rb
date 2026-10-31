require_relative "abstract/places_with_most_competitions_by_year"

class CitiesWithMostCompetitionsByYear < PlacesWithMostCompetitionsByYear
  def initialize
    super(place: "City", places: "Cities", note: "Only the 20 cities with the most competitions are listed for each year.")
  end

  def place_for(row)
    row["city_name"]
  end
end
