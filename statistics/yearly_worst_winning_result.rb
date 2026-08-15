require_relative "./abstract/worst_qualifying_results"

class YearlyWorstWinningResult < WorstQualifyingResults
  def initialize
    super(
      title: "Worst result providing a win by year at Polish competitions",
      note: "Only finals at competitions held in Poland are taken into account, regardless of the winners' countries. Results where the main statistic is DNF are ignored. Each year is considered separately.",
      max_position: 1,
      condition: "AND competition.country_id = 'Poland'",
      yearly: true
    )
  end
end
