# frozen_string_literal: true

require 'spec_helper'
require 'active_record'
require 'servus/extensions/lazily/ext'

# ── Database Setup ───────────────────────────────────────────────────────────

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :email, null: false
    t.string :name, null: false
    t.decimal :balance, precision: 10, scale: 2, default: 0
    t.timestamps null: false
  end

  create_table :orders, force: true do |t|
    t.integer :user_id, null: false
    t.decimal :total, precision: 10, scale: 2, null: false
    t.string :status, default: 'pending'
    t.timestamps null: false
  end
end

# ── Models ───────────────────────────────────────────────────────────────────

class User < ActiveRecord::Base
  has_many :orders
end

class Order < ActiveRecord::Base
  belongs_to :user
end

# ── Load Extension ───────────────────────────────────────────────────────────

Servus::Base.extend Servus::Extensions::Lazily::Call unless Servus::Base.respond_to?(:lazily)

# ── Services ─────────────────────────────────────────────────────────────────

module Integration
  class ProcessPayment < Servus::Base
    lazily :user, finds: User
    lazily :order, finds: Order

    schema(
      result: {
        type: 'object',
        required: %w[charged_amount],
        properties: {
          charged_amount: { type: 'number' }
        }
      },
      failure: {
        type: 'object',
        required: %w[reason],
        properties: {
          reason: { type: 'string' },
          balance: { type: 'number' }
        }
      }
    )

    def initialize(user:, order:)
      @user = user
      @order = order
    end

    def call
      if user.balance < order.total
        return failure(
          'Insufficient funds',
          data: { reason: 'insufficient_balance', balance: user.balance.to_f },
          type: Servus::Support::Errors::UnprocessableEntityError
        )
      end

      success(charged_amount: order.total.to_f, user_name: user.name)
    end
  end

  class NotifyUsers < Servus::Base
    lazily :sender, finds: User, by: :email
    lazily :recipients, finds: User

    def initialize(sender:, recipients:, message:)
      @sender = sender
      @recipients = recipients
      @message = message
    end

    def call
      success(
        from: sender.email,
        to_count: recipients.length,
        message: @message
      )
    end
  end
end

# ── Specs ────────────────────────────────────────────────────────────────────

RSpec.describe 'Feature integration' do
  before do
    Servus::Support::Validator.clear_cache!
    User.delete_all
    Order.delete_all
  end

  let(:alice) { User.create!(email: 'alice@example.com', name: 'Alice', balance: 500) }
  let(:bob) { User.create!(email: 'bob@example.com', name: 'Bob', balance: 10) }
  let(:order) { Order.create!(user: alice, total: 99.99) }

  describe 'ProcessPayment' do
    context 'with IDs (async-compatible)' do
      it 'resolves records lazily, validates result schema, and returns DataObject' do
        result = Integration::ProcessPayment.call(user: alice.id, order: order.id)

        expect(result).to be_success
        expect(result.data).to be_a(Servus::Support::DataObject)
        expect(result.data.charged_amount).to eq(99.99)
        expect(result.data.user_name).to eq('Alice')
        expect(result.data[:charged_amount]).to eq(99.99)
      end
    end

    context 'with loaded instances (sync, no extra queries)' do
      it 'skips database queries and uses the instances directly' do
        loaded_user = alice
        loaded_order = order

        expect(User).not_to receive(:find)
        expect(Order).not_to receive(:find)

        result = Integration::ProcessPayment.call(user: loaded_user, order: loaded_order)

        expect(result).to be_success
        expect(result.data.charged_amount).to eq(99.99)
      end
    end

    context 'with insufficient balance' do
      it 'returns failure with validated data, correct error type, and DataObject accessors' do
        result = Integration::ProcessPayment.call(user: bob.id, order: order.id)

        expect(result).to be_failure
        expect(result.error).to be_a(Servus::Support::Errors::UnprocessableEntityError)
        expect(result.data).to be_a(Servus::Support::DataObject)
        expect(result.data.reason).to eq('insufficient_balance')
        expect(result.data.balance).to eq(10.0)
        expect(result.data[:reason]).to eq('insufficient_balance')
      end
    end

    context 'with nil user' do
      it 'raises NotFoundError before any database query' do
        expect do
          Integration::ProcessPayment.call(user: nil, order: order.id)
        end.to raise_error(
          Servus::Extensions::Lazily::Errors::NotFoundError,
          /user was nil/
        )
      end
    end

    context 'with nonexistent record' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect do
          Integration::ProcessPayment.call(user: 999_999, order: order.id)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'NotifyUsers' do
    context 'with custom column lookup and array input' do
      it 'resolves sender by email and recipients by ID array' do
        result = Integration::NotifyUsers.call(
          sender: alice.email,
          recipients: [alice.id, bob.id],
          message: 'Hello everyone'
        )

        expect(result).to be_success
        expect(result.data.from).to eq('alice@example.com')
        expect(result.data.to_count).to eq(2)
        expect(result.data.message).to eq('Hello everyone')
      end
    end

    context 'with loaded sender instance (skips find_by!)' do
      it 'uses the instance directly without querying' do
        loaded_alice = alice
        bob

        expect(User).not_to receive(:find_by!)

        result = Integration::NotifyUsers.call(
          sender: loaded_alice,
          recipients: [loaded_alice.id, bob.id],
          message: 'Hello'
        )

        expect(result).to be_success
        expect(result.data.from).to eq('alice@example.com')
      end
    end

    context 'with empty recipients array' do
      it 'returns empty list without raising' do
        result = Integration::NotifyUsers.call(
          sender: alice.email,
          recipients: [],
          message: 'Hello'
        )

        expect(result).to be_success
        expect(result.data.to_count).to eq(0)
      end
    end
  end
end
