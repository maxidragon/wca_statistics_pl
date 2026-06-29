require 'json'

module Voivodeships
  POLYGONS = begin
    features = JSON.parse(File.read(File.expand_path("data/voivodeships.geojson", __dir__)))["features"]
    features.each_with_object({}) do |feature, hash|
      name = feature["properties"]["nazwa"]
      hash[name] = feature["geometry"]["coordinates"][0]
    end
  end.freeze

  ALL = POLYGONS.keys.sort.freeze

  def voivodeship_for(lat, lon)
    POLYGONS.each do |name, ring|
      return name if point_in_ring?(lon.to_f, lat.to_f, ring)
    end
    nil
  end

  def voivodeship_display_name(voiv)
    voiv.split('-').map { |w| w[0].upcase + w[1..] }.join('-')
  end

  private

  def point_in_ring?(x, y, ring)
    inside = false
    j = ring.length - 1
    ring.length.times do |i|
      xi, yi = ring[i]
      xj, yj = ring[j]
      if ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
        inside = !inside
      end
      j = i
    end
    inside
  end
end
