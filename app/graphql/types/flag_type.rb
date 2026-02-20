# frozen_string_literal: true

module Types
  class FlagType < Types::BaseObject
    implements Types::NodeType
    field :id, ID, null: false
    field :key, String, null: false
    field :enabled, Boolean, null: false
    field :description, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
