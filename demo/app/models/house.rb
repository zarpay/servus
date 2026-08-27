# =============================================================================
# House
# =============================================================================
#
# A plain ActiveRecord model. Nothing here knows about Servus — that is the
# point. Services orchestrate; models stay ordinary.
#
# This model is the target of Servus's `lazily` resolver, which is why it has
# two things worth resolving by: an `id` (the default) and a unique `name`
# (the `by:` option). See `app/services/ledger/record_entry/service.rb`.
class House < ApplicationRecord
  has_one  :vault, dependent: :destroy
  has_many :ravens, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  # Standing is checked by Servus's built-in StateGuard rather than by an
  # ActiveRecord validation, because it is a precondition of *acting*, not a
  # rule about whether the record may be saved.
  STANDINGS = %w[loyal neutral rebellious].freeze

  validates :standing, inclusion: { in: STANDINGS }
end
