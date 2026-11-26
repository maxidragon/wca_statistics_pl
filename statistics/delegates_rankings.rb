require_relative "./abstract/rankings"

class DelegatesRankings < Rankings
  def initialize
    super(
      title: "Delegates rankings",
      note: "Only current delegates (including trainees) are taken into account.",
      condition: <<-SQL
        WHERE EXISTS (
          SELECT 1
          FROM users user
          JOIN user_roles user_role ON user_role.user_id = user.id
          WHERE user.wca_id = person.wca_id
            AND user_role.metadata_type = 'RolesMetadataDelegateRegions'
            AND user_role.start_date <= CURDATE()
            AND (user_role.end_date IS NULL OR user_role.end_date > CURDATE())
        )
      SQL
    )
  end
end
