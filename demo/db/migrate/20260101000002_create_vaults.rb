# =============================================================================
# vaults — where the gold lives
# =============================================================================
#
# `gold_dragons` is a plain integer. This demo is about Servus, not about money
# representation — the sibling `amounts` gem exists for that. Keeping it an
# integer means a schema can describe it with a bare
# `{ type: 'integer', minimum: 0 }` and the reader's attention stays on the
# service layer.
#
# `sealed` gives the Truthy/Falsey guards something to check that is not the
# same attribute the StateGuard uses.
class CreateVaults < ActiveRecord::Migration[8.1]
  def change
    create_table :vaults do |t|
      t.references :house, null: false, foreign_key: true
      t.integer :gold_dragons, null: false, default: 0
      t.boolean :sealed,       null: false, default: false

      t.timestamps
    end

    add_index :vaults, :gold_dragons
  end
end
