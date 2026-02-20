# frozen_string_literal: true

module Types
  class EvaluateResultType < Types::BaseObject
    description "Result of evaluating a flag: enabled state and whether the flag was found"
    field :enabled, Boolean, null: false, description: "Whether the flag is enabled (false if flag not found)"
    field :flag_not_found, Boolean, null: false, description: "True when the flag key does not exist"
  end
end
