# =============================================================================
# ravens — messages dispatched asynchronously
# =============================================================================
#
# Ravens are written by services that run in background jobs, so this table is
# how the specs prove that an enqueued reaction actually executed rather than
# merely being scheduled.
class CreateRavens < ActiveRecord::Migration[8.1]
  def change
    create_table :ravens do |t|
      t.references :house, null: false, foreign_key: true
      t.string  :message,     null: false
      t.string  :destination, null: false, default: "kings_landing"
      t.datetime :dispatched_at

      t.timestamps
    end
  end
end
