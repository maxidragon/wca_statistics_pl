module Voivodeships
  BOUNDARIES = {
    "dolnośląskie"        => [50.09, 51.74, 15.03, 17.93],
    "kujawsko-pomorskie"  => [52.58, 53.81, 17.45, 19.85],
    "lubelskie"           => [50.33, 51.64, 22.01, 24.15],
    "lubuskie"            => [51.08, 52.92, 14.12, 16.12],
    "łódzkie"             => [51.00, 52.25, 18.17, 20.28],
    "małopolskie"         => [49.33, 50.50, 19.15, 21.25],
    "mazowieckie"         => [51.40, 53.55, 19.00, 22.00],
    "opolskie"            => [50.17, 51.13, 17.33, 18.77],
    "podkarpackie"        => [49.00, 50.55, 21.28, 23.53],
    "podlaskie"           => [52.60, 54.50, 22.75, 23.85],
    "pomorskie"           => [53.60, 55.15, 16.50, 19.75],
    "śląskie"             => [49.40, 50.75, 18.00, 19.95],
    "świętokrzyskie"      => [50.30, 51.15, 19.90, 21.45],
    "warmińsko-mazurskie" => [53.50, 54.45, 19.20, 22.95],
    "wielkopolskie"       => [51.60, 53.50, 16.10, 18.90],
    "zachodniopomorskie"  => [53.05, 54.35, 14.10, 16.70],
  }.freeze

  ALL = BOUNDARIES.keys.freeze

  def voivodeship_for(lat, lon)
    candidates = BOUNDARIES.select do |_, (lat_min, lat_max, lon_min, lon_max)|
      lat.to_f >= lat_min && lat.to_f <= lat_max &&
        lon.to_f >= lon_min && lon.to_f <= lon_max
    end
    candidates.min_by { |_, (lat_min, lat_max, lon_min, lon_max)| (lat_max - lat_min) * (lon_max - lon_min) }&.first
  end

  def voivodeship_display_name(voiv)
    voiv.split('-').map { |w| w[0].upcase + w[1..] }.join('-')
  end
end
