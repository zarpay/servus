# =============================================================================
# ledger_entries — the audit trail written by an event reaction
# =============================================================================
#
# Nothing in the Treasury writes this table directly. `Ledger::RecordEntry::Service`
# does, and it is only ever reached because `GoldTransferredEvent` enqueues it.
#
# That indirection is the point: the specs assert that a transfer produces a
# ledger entry *without* the transfer service knowing the ledger exists.
class CreateLedgerEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :ledger_entries do |t|
      t.references :vault, null: false, foreign_key: true
      t.integer :amount,    null: false
      t.string  :direction, null: false
      t.string  :memo

      t.timestamps
    end

    add_index :ledger_entries, :direction
  end
end
