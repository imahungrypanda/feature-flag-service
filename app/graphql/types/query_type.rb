# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :node, Types::NodeType, null: true, description: "Fetches an object given its ID." do
      argument :id, ID, required: true, description: "ID of the object."
    end

    def node(id:)
      context.schema.object_from_id(id, context)
    end

    field :nodes, [Types::NodeType, null: true], null: true, description: "Fetches a list of objects given a list of IDs." do
      argument :ids, [ID], required: true, description: "IDs of the objects."
    end

    def nodes(ids:)
      ids.map { |id| context.schema.object_from_id(id, context) }
    end

    field :flag, Types::FlagType, null: true, description: "Retrieve a flag by key." do
      argument :key, String, required: true, description: "The flag key."
    end

    def flag(key:)
      Flag.find_by(key: key)
    end

    field :evaluate_flag, Types::EvaluateResultType, null: false, description: "Evaluate a flag by key; returns enabled state and whether the flag was found." do
      argument :key, String, required: true, description: "The flag key to evaluate."
      argument :user_id, String, required: false, description: "Optional user id for future targeting."
      argument :attributes, GraphQL::Types::JSON, required: false, description: "Optional attributes for future targeting."
    end

    def evaluate_flag(key:, user_id: nil, attributes: nil)
      flag = Flag.find_by(key: key)
      if flag
        { enabled: flag.enabled, flag_not_found: false }
      else
        { enabled: false, flag_not_found: true }
      end
    end

    field :test_field, String, null: false,
      description: "An example field added by the generator"
    def test_field
      "Hello World!"
    end
  end
end
