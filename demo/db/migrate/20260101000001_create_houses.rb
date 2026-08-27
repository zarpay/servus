# =============================================================================
# houses — the actor in every scenario
# =============================================================================
#
# A House is the owner of a Vault and the sender/recipient of Ravens. It exists
# mainly to give the `lazily` resolver something to resolve, and to give guards
# a record whose attributes they can inspect.
#
# `standing` drives Servus's built-in StateGuard:
#
#   enforce_state!(on: house, check: :standing, is: %w[loyal neutral])
#
# so it deliberately has more than two values — a boolean would only exercise
# the Truthy/Falsey guards, and we want a genuine state check too.
class CreateHouses < ActiveRecord::Migration[8.1]
  def change
    create_table :houses do |t|
      t.string  :name,     null: false
      t.string  :sigil
      t.string  :standing, null: false, default: "loyal"
      t.boolean :attainted, null: false, default: false

      t.timestamps
    end

    add_index :houses, :name, unique: true
  end
end
