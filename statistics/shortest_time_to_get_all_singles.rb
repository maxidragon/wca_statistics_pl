require_relative "abstract/shortest_time_to_get_all_results"

class ShortestTimeToGetAllSingles < ShortestTimeToGetAllResults
  def initialize
    super(with_averages: false)
  end
end
