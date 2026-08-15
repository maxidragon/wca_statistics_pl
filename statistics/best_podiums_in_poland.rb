require_relative "./abstract/best_podiums"

class BestPodiumsInPoland < BestPodiums
  def initialize
    super(
      title: "Best podiums at Polish competitions",
      note: "Podiums at competitions held in Poland, regardless of the podium members' countries. Podium places with sum of best or average times depending on format.",
      condition: <<-SQL
        AND competition.country_id = 'Poland'
      SQL
    )
  end
end
