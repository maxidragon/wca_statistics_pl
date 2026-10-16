require_relative "abstract/first_competition_to_role_gap"

class MostCompetitionsAttendedBeforeOrganizing < FirstCompetitionToRoleGap
  def initialize
    super(role: :organizer, metric: :competitions)
  end
end
