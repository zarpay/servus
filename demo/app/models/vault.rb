# =============================================================================
# Vault
# =============================================================================
#
# Holds gold and knows how to move it. The `withdraw!` / `deposit!` methods are
# deliberately dumb: they do not check whether there is enough gold, because
# that check belongs to a Servus guard
# (`app/guards/sufficient_gold_guard.rb`), not to the model.
#
# Keeping the precondition out of the model is what lets the guard produce a
# structured `GuardError` with an HTTP status and an error code, which the
# controller then renders. A model-level `raise` could not carry that.
class Vault < ApplicationRecord
  belongs_to :house
  has_many :ledger_entries, dependent: :destroy

  validates :gold_dragons, numericality: { greater_than_or_equal_to: 0 }

  def withdraw!(amount)
    update!(gold_dragons: gold_dragons - amount)
  end

  def deposit!(amount)
    update!(gold_dragons: gold_dragons + amount)
  end
end
