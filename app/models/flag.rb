# frozen_string_literal: true

class Flag < ApplicationRecord
  validates :key, presence: true, uniqueness: true
end
