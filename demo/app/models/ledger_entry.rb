# =============================================================================
# LedgerEntry
# =============================================================================
#
# Written only by `Ledger::RecordEntry::Service`, which is only ever reached
# because `GoldTransferredEvent` enqueues it. Specs use the presence of a row
# here to prove an event reaction ran.
class LedgerEntry < ApplicationRecord
  belongs_to :vault

  DIRECTIONS = %w[debit credit].freeze

  validates :direction, inclusion: { in: DIRECTIONS }
  validates :amount, numericality: { other_than: 0 }
end
