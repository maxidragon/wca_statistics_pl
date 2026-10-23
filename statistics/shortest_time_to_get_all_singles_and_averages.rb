require_relative "abstract/shortest_time_to_get_all_results"

class ShortestTimeToGetAllSinglesAndAverages < ShortestTimeToGetAllResults
  def initialize
    super(with_averages: true)
  end
end
