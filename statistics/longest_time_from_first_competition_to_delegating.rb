require_relative "abstract/first_competition_to_role_gap"

class LongestTimeFromFirstCompetitionToDelegating < FirstCompetitionToRoleGap
  def initialize
    super(role: :delegate, metric: :days)
  end
end
