# frozen_string_literal: true

module Mutations
  class UpdateFlag < BaseMutation
    description "Update a feature flag's state (e.g. toggle enabled)"

    argument :key, String, required: true, description: "Key of the flag to update"
    argument :enabled, Boolean, required: true, description: "New enabled state"

    field :flag, Types::FlagType, null: true, description: "The updated flag"
    field :errors, [String], null: false, description: "Errors (e.g. not found)"

    def resolve(key:, enabled:)
      flag = Flag.find_by(key: key)
      unless flag
        return { flag: nil, errors: ["Flag not found: #{key}"] }
      end
      if flag.update(enabled: enabled)
        { flag: flag, errors: [] }
      else
        { flag: nil, errors: flag.errors.full_messages }
      end
    end
  end
end
