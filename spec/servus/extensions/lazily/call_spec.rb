# frozen_string_literal: true

require 'spec_helper'

require 'active_record'

# Fake model class simulating ActiveRecord behavior
class FakeModel
  attr_reader :id, :email, :uuid

  def initialize(id: nil, email: nil, uuid: nil)
    @id = id
    @email = email
    @uuid = uuid
  end

  def self.find(id)
    raise ActiveRecord::RecordNotFound, "Couldn't find FakeModel with id=#{id}" if id == 999

    new(id: id)
  end

  def self.find_by!(**attrs)
    value = attrs.values.first
    raise ActiveRecord::RecordNotFound, "Couldn't find FakeModel" if value == 'missing'

    new(**attrs)
  end

  def self.where(**attrs)
    values = Array(attrs.values.first)
    values.map { |v| new(id: v) }
  end
end

# Second fake model for multi-resolver tests
class FakeAccount
  attr_reader :id, :uuid

  def initialize(id: nil, uuid: nil)
    @id = id
    @uuid = uuid
  end

  def self.find(id)
    new(id: id)
  end

  def self.find_by!(**attrs)
    value = attrs.values.first
    raise ActiveRecord::RecordNotFound, "Couldn't find FakeAccount" if value == 'missing'

    new(**attrs)
  end

  def self.where(**attrs)
    values = Array(attrs.values.first)
    values.map { |v| new(uuid: v) }
  end
end

# Load the extension manually since we don't have a Railtie in tests
require 'servus/extensions/lazily/ext'
Servus::Base.extend Servus::Extensions::Lazily::Call

RSpec.describe Servus::Extensions::Lazily::Call do
  describe 'DSL registration' do
    it 'stores resolver config in lazy_resolvers' do
      service_class = Class.new(Servus::Base) do
        lazily :user, finds: FakeModel
      end

      expect(service_class.lazy_resolvers[:user]).to eq({ klass: FakeModel, by: :id })
    end

    it 'accumulates multiple lazily declarations' do
      service_class = Class.new(Servus::Base) do
        lazily :user, finds: FakeModel
        lazily :account, finds: FakeAccount, by: :uuid
      end

      expect(service_class.lazy_resolvers.keys).to eq(%i[user account])
    end

    it 'returns empty hash when none defined' do
      service_class = Class.new(Servus::Base)
      expect(service_class.lazy_resolvers).to eq({})
    end
  end

  describe 'resolution with ID (default .find)' do
    let(:service_class) do
      Class.new(Servus::Base) do
        lazily :user, finds: FakeModel

        def initialize(user:)
          @user = user
        end

        def call
          success(user: user)
        end
      end
    end

    it 'resolves an integer ID to a record via .find' do
      instance = service_class.new(user: 42)
      resolved = instance.user

      expect(resolved).to be_a(FakeModel)
      expect(resolved.id).to eq(42)
    end

    it 'resolves a string ID to a record via .find' do
      instance = service_class.new(user: '42')
      resolved = instance.user

      expect(resolved).to be_a(FakeModel)
      expect(resolved.id).to eq('42')
    end

    it 'memoizes the result — .find is only called once' do
      expect(FakeModel).to receive(:find).with(42).once.and_call_original

      instance = service_class.new(user: 42)
      first_call = instance.user
      second_call = instance.user

      expect(first_call).to equal(second_call)
    end

    it 'writes resolved record back to the ivar' do
      instance = service_class.new(user: 42)
      instance.user

      raw = instance.instance_variable_get(:@user)
      expect(raw).to be_a(FakeModel)
      expect(raw.id).to eq(42)
    end
  end

  describe 'resolution with instance (skip query)' do
    let(:service_class) do
      Class.new(Servus::Base) do
        lazily :user, finds: FakeModel

        def initialize(user:)
          @user = user
        end

        def call
          success(user: user)
        end
      end
    end

    it 'returns instance directly when value is_a? target class' do
      existing_user = FakeModel.new(id: 7, email: 'alice@example.com')
      instance = service_class.new(user: existing_user)

      expect(instance.user).to equal(existing_user)
    end

    it 'does not call .find when value is already an instance' do
      existing_user = FakeModel.new(id: 7)

      expect(FakeModel).not_to receive(:find)

      instance = service_class.new(user: existing_user)
      instance.user
    end
  end

  describe 'resolution with custom column (by:)' do
    let(:service_class) do
      Class.new(Servus::Base) do
        lazily :account, finds: FakeAccount, by: :uuid

        def initialize(account:)
          @account = account
        end

        def call
          success(account: account)
        end
      end
    end

    it 'resolves via .find_by! with a string value' do
      instance = service_class.new(account: 'abc-def-123')
      resolved = instance.account

      expect(resolved).to be_a(FakeAccount)
      expect(resolved.uuid).to eq('abc-def-123')
    end

    it 'resolves via .find_by! with an integer value' do
      instance = service_class.new(account: 42)
      resolved = instance.account

      expect(resolved).to be_a(FakeAccount)
    end

    it 'raises when .find_by! raises (record not found)' do
      instance = service_class.new(account: 'missing')

      expect { instance.account }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'nil handling' do
    let(:service_class) do
      Class.new(Servus::Base) do
        lazily :user, finds: FakeModel

        def initialize(user:)
          @user = user
        end

        def call
          success(user: user)
        end
      end
    end

    it 'raises NotFoundError with descriptive message' do
      instance = service_class.new(user: nil)

      expect { instance.user }.to raise_error(
        Servus::Extensions::Lazily::Errors::NotFoundError,
        /Couldn't find FakeModel/
      )
    end

    it 'includes the param name in the error message' do
      instance = service_class.new(user: nil)

      expect { instance.user }.to raise_error(
        Servus::Extensions::Lazily::Errors::NotFoundError,
        /user was nil/
      )
    end
  end

  describe 'array input' do
    let(:service_class) do
      Class.new(Servus::Base) do
        lazily :users, finds: FakeModel

        def initialize(users:)
          @users = users
        end

        def call
          success(users: users)
        end
      end
    end

    it 'resolves array of IDs via .where' do
      instance = service_class.new(users: [1, 2, 3])
      resolved = instance.users

      expect(resolved).to be_a(Array)
      expect(resolved.length).to eq(3)
      expect(resolved.first).to be_a(FakeModel)
    end

    it 'resolves array with custom column via .where' do
      svc = Class.new(Servus::Base) do
        lazily :accounts, finds: FakeAccount, by: :uuid

        def initialize(accounts:)
          @accounts = accounts
        end

        def call
          success(accounts: accounts)
        end
      end

      instance = svc.new(accounts: %w[uuid-1 uuid-2])
      resolved = instance.accounts

      expect(resolved).to be_a(Array)
      expect(resolved.length).to eq(2)
    end

    it 'returns empty result for empty array (no raise)' do
      instance = service_class.new(users: [])
      resolved = instance.users

      expect(resolved).to be_a(Array)
      expect(resolved).to be_empty
    end

    it 'memoizes the result — .where is only called once' do
      expect(FakeModel).to receive(:where).once.and_call_original

      instance = service_class.new(users: [1, 2])
      first_call = instance.users
      second_call = instance.users

      expect(first_call).to equal(second_call)
    end
  end

  describe 'multiple resolvers on same service' do
    let(:service_class) do
      Class.new(Servus::Base) do
        lazily :user, finds: FakeModel
        lazily :account, finds: FakeAccount, by: :uuid

        def initialize(user:, account:)
          @user = user
          @account = account
        end

        def call
          success(user: user, account: account)
        end
      end
    end

    it 'resolves each independently' do
      instance = service_class.new(user: 1, account: 'abc-123')

      expect(instance.user).to be_a(FakeModel)
      expect(instance.user.id).to eq(1)
      expect(instance.account).to be_a(FakeAccount)
      expect(instance.account.uuid).to eq('abc-123')
    end

    it 'memoizes each separately' do
      instance = service_class.new(user: 1, account: 'abc-123')

      user1 = instance.user
      account1 = instance.account
      user2 = instance.user
      account2 = instance.account

      expect(user1).to equal(user2)
      expect(account1).to equal(account2)
    end
  end

  describe 'dry-initializer compatibility' do
    it 'works when ivar is set by an alternative initializer' do
      service_class = Class.new(Servus::Base) do
        lazily :user, finds: FakeModel

        # Simulating dry-initializer setting the ivar
        def initialize(user:)
          @user = user
        end
      end

      instance = service_class.new(user: 42)
      expect(instance.user).to be_a(FakeModel)
      expect(instance.user.id).to eq(42)
    end
  end

  describe 'integration with service .call' do
    module LazilyTest
      class PaymentService < Servus::Base
        lazily :user, finds: FakeModel

        def initialize(user:, amount:)
          @user = user
          @amount = amount
        end

        def call
          success(user: user, charged: @amount)
        end
      end
    end

    it 'resolves lazily during call with an ID' do
      result = LazilyTest::PaymentService.call(user: 42, amount: 100)

      expect(result).to be_success
      expect(result.data[:user]).to be_a(FakeModel)
      expect(result.data[:user].id).to eq(42)
    end

    it 'passes through an already-loaded instance' do
      existing = FakeModel.new(id: 7, email: 'test@example.com')
      result = LazilyTest::PaymentService.call(user: existing, amount: 100)

      expect(result).to be_success
      expect(result.data[:user]).to equal(existing)
    end
  end

  describe 'edge cases' do
    it 'does not resolve if the accessor is never called' do
      service_class = Class.new(Servus::Base) do
        lazily :user, finds: FakeModel

        def initialize(user:)
          @user = user
        end

        def call
          success(skipped: true)
        end
      end

      expect(FakeModel).not_to receive(:find)
      service_class.new(user: 42).call
    end

    it 'raises ActiveRecord::RecordNotFound when .find fails' do
      service_class = Class.new(Servus::Base) do
        lazily :user, finds: FakeModel

        def initialize(user:)
          @user = user
        end

        def call
          success(user: user)
        end
      end

      instance = service_class.new(user: 999)
      expect { instance.user }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
