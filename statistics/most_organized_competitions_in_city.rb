require_relative "abstract/role_competitions_in_city"

class MostOrganizedCompetitionsInCity < RoleCompetitionsInCity
  def initialize
    super(role: :organizer)
  end
end
