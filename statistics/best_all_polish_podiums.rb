require_relative "./abstract/best_podiums"

class BestAllPolishPodiums < BestPodiums
  def initialize
    super(
      title: "Best all-Polish podiums",
      note: "Podiums at any competition where all three podium places were taken by people representing Poland. Podium places with sum of best or average times depending on format.",
      condition: <<-SQL
        AND results.country_id = 'Poland'
        AND NOT EXISTS (
          SELECT 1 FROM results r3
          WHERE r3.competition_id = results.competition_id
            AND r3.event_id = results.event_id
            AND r3.round_type_id = results.round_type_id
            AND r3.pos IN (1, 2, 3)
            AND r3.best > 0
            AND r3.country_id != 'Poland'
        )
      SQL
    )
  end
end
