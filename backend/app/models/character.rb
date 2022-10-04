class Character < ActiveRecord::Base
  include PgSearch::Model
  pg_search_scope :search_by_term, against: %i[name alias_names], using: {
    tsearch: {
      any_word: true,
      prefix: true
    }
  }

  default_scope { order(name: :asc) }
end
