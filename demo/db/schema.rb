# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_01_000004) do
  create_table "houses", force: :cascade do |t|
    t.boolean "attainted", default: false, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "sigil"
    t.string "standing", default: "loyal", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_houses_on_name", unique: true
  end

  create_table "ledger_entries", force: :cascade do |t|
    t.integer "amount", null: false
    t.datetime "created_at", null: false
    t.string "direction", null: false
    t.string "memo"
    t.datetime "updated_at", null: false
    t.integer "vault_id", null: false
    t.index ["direction"], name: "index_ledger_entries_on_direction"
    t.index ["vault_id"], name: "index_ledger_entries_on_vault_id"
  end

  create_table "ravens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "destination", default: "kings_landing", null: false
    t.datetime "dispatched_at"
    t.integer "house_id", null: false
    t.string "message", null: false
    t.datetime "updated_at", null: false
    t.index ["house_id"], name: "index_ravens_on_house_id"
  end

  create_table "vaults", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "gold_dragons", default: 0, null: false
    t.integer "house_id", null: false
    t.boolean "sealed", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["gold_dragons"], name: "index_vaults_on_gold_dragons"
    t.index ["house_id"], name: "index_vaults_on_house_id"
  end

  add_foreign_key "ledger_entries", "vaults"
  add_foreign_key "ravens", "houses"
  add_foreign_key "vaults", "houses"
end
