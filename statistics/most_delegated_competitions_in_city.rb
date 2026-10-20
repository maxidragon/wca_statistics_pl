require_relative "abstract/role_competitions_in_city"

class MostDelegatedCompetitionsInCity < RoleCompetitionsInCity
  def initialize
    super(role: :delegate)
  end
end
