require_relative "abstract/first_competition_to_role_gap"

class LongestTimeFromFirstCompetitionToOrganizing < FirstCompetitionToRoleGap
  def initialize
    super(role: :organizer, metric: :days)
  end
end
