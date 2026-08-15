require_relative "./abstract/worst_qualifying_results"

class WorstWinningResult < WorstQualifyingResults
  def initialize
    super(
      title: "Worst result providing a win",
      note: "Only finals are taken into account. Results where the main statistic is DNF are ignored.",
      max_position: 1,
      joins: <<-SQL
        JOIN persons person ON person.wca_id = results.person_id AND person.sub_id = 1 AND person.country_id = 'Poland'
      SQL
    )
  end
end
