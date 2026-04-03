# frozen_string_literal: true

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :email, null: false
    t.string :name, null: false
    t.decimal :balance, precision: 10, scale: 2, default: 0
    t.timestamps
  end

  add_index :users, :email, unique: true

  create_table :orders, force: true do |t|
    t.references :user, null: false
    t.decimal :total, precision: 10, scale: 2, null: false
    t.string :status, default: 'pending'
    t.timestamps
  end
end
