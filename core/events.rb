require "date"

module Events
  ALL = {
    "333"     => "3x3x3 Cube",
    "222"     => "2x2x2 Cube",
    "444"     => "4x4x4 Cube",
    "555"     => "5x5x5 Cube",
    "666"     => "6x6x6 Cube",
    "777"     => "7x7x7 Cube",
    "333bf"   => "3x3x3 Blindfolded",
    "333fm"   => "3x3x3 Fewest Moves",
    "333oh"   => "3x3x3 One-Handed",
    "minx"    => "Megaminx",
    "pyram"   => "Pyraminx",
    "clock"   => "Clock",
    "skewb"   => "Skewb",
    "sq1"     => "Square-1",
    "444bf"   => "4x4x4 Blindfolded",
    "555bf"   => "5x5x5 Blindfolded",
    "333mbf"  => "3x3x3 Multi-Blind",
    "333ft"   => "3x3x3 With Feet",
    "magic"   => "Rubik's Magic",
    "mmagic"  => "Master Magic",
    "333mbo"  => "3x3x3 Multi-Blind Old-Style",
    "fto"     => "Face-Turning Octahedron",
  }

  OFFICIAL = ALL.first(17).to_h

  # Days on which each event was official, as [first day, first day no longer official].
  # Dates come from the Regulations version that added or removed the event
  # (https://www.worldcubeassociation.org/regulations/history/), or from the first
  # and last competition holding it where no Regulations version covers the change.
  OFFICIAL_PERIODS = {
    "333"     => [Date.new(1982, 6, 5), nil],
    "222"     => [Date.new(2004, 11, 7), nil],
    "444"     => [Date.new(2003, 8, 23), nil],
    "555"     => [Date.new(2003, 8, 23), nil],
    "666"     => [Date.new(2009, 2, 6), nil],
    "777"     => [Date.new(2009, 2, 6), nil],
    "333bf"   => [Date.new(2003, 8, 23), nil],
    "333fm"   => [Date.new(2003, 8, 23), nil],
    "333oh"   => [Date.new(2003, 8, 23), nil],
    "minx"    => [Date.new(2003, 8, 23), nil],
    "pyram"   => [Date.new(2003, 8, 23), nil],
    "clock"   => [Date.new(2003, 8, 23), nil],
    "skewb"   => [Date.new(2014, 1, 1), nil],
    "sq1"     => [Date.new(2003, 8, 23), nil],
    "444bf"   => [Date.new(2003, 8, 23), nil],
    "555bf"   => [Date.new(2003, 8, 23), nil],
    "333mbf"  => [Date.new(2007, 2, 1), nil],
    "333ft"   => [Date.new(2004, 8, 7), Date.new(2020, 1, 1)],
    "magic"   => [Date.new(2003, 8, 23), Date.new(2013, 1, 1)],
    "mmagic"  => [Date.new(2003, 8, 23), Date.new(2013, 1, 1)],
    "333mbo"  => [Date.new(2005, 10, 16), Date.new(2009, 2, 1)],
    "fto"     => [Date.new(2027, 1, 2), nil],
  }

  WITHOUT_AVERAGE = %w(333mbf 333mbo)

  def self.official_on(date)
    OFFICIAL_PERIODS
      .select { |event_id, (from, to)| from <= date && (to.nil? || date < to) }
      .keys
  end

  BLD = ALL.select { |event_id, event_name| %w(333bf 444bf 555bf 333mbf).include?(event_id) }
end
