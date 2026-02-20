# frozen_string_literal: true

module Mutations
  class CreateFlag < BaseMutation
    description "Create a feature flag with a unique key and optional metadata"

    argument :key, String, required: true, description: "Unique key for the flag"
    argument :enabled, Boolean, required: false, description: "Whether the flag is enabled (default: false)"
    argument :description, String, required: false, description: "Optional description or metadata"

    field :flag, Types::FlagType, null: true, description: "The created flag"
    field :errors, [String], null: false, description: "Validation errors"

    def resolve(key:, enabled: false, description: nil)
      flag = Flag.new(key: key, enabled: enabled, description: description)
      if flag.save
        { flag: flag, errors: [] }
      else
        { flag: nil, errors: flag.errors.full_messages }
      end
    end
  end
end
