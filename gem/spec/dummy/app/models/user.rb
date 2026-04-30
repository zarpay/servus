# frozen_string_literal: true

class User < ActiveRecord::Base
  has_many :orders
end
