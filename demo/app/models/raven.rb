# =============================================================================
# Raven
# =============================================================================
#
# A dispatched message. Rows appear here only after a background job has run,
# so specs that assert on Ravens are proving end-to-end async behaviour rather
# than just that a job was enqueued.
class Raven < ApplicationRecord
  belongs_to :house

  validates :message, presence: true

  scope :dispatched, -> { where.not(dispatched_at: nil) }
end
