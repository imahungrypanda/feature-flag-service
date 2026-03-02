# frozen_string_literal: true

module GraphqlRequestHelpers
  def graphql_query(query, variables: {}, token: default_token)
    headers = {}
    headers["Authorization"] = "Bearer #{token}" if token
    post "/graphql", params: { query: query, variables: variables }, headers: headers, as: :json
  end

  private

  def default_token
    ENV["FEATURE_FLAG_API_TOKEN"] ||= "test-token"
  end
end
