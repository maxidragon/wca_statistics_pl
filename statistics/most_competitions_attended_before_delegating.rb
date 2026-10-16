require_relative "abstract/first_competition_to_role_gap"

class MostCompetitionsAttendedBeforeDelegating < FirstCompetitionToRoleGap
  def initialize
    super(role: :delegate, metric: :competitions)
  end
end
