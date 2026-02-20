# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :create_flag, mutation: Mutations::CreateFlag
    field :update_flag, mutation: Mutations::UpdateFlag
  end
end
