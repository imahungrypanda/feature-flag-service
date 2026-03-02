# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GraphQL API", type: :request do
  let(:valid_token) { "test-token" }
  let(:invalid_token) { "bad-token" }

  describe "authentication" do
    let(:query) { "{ flag(key: \"nonexistent\") { key } }" }

    it "rejects requests without a token" do
      graphql_query(query, token: nil)
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["errors"].first["message"]).to eq("Unauthorized")
    end

    it "rejects requests with an invalid token" do
      graphql_query(query, token: invalid_token)
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["errors"].first["message"]).to eq("Unauthorized")
    end

    it "allows requests with the valid token" do
      graphql_query(query)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "query: flag" do
    it "returns null when flag does not exist" do
      graphql_query(<<~GQL)
        query { flag(key: "nonexistent") { id key enabled } }
      GQL
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]["flag"]).to be_nil
    end

    it "returns the flag when it exists" do
      flag = Flag.create!(key: "my_flag", enabled: true, description: "A test flag")
      graphql_query(<<~GQL)
        query { flag(key: "my_flag") { id key enabled description } }
      GQL
      expect(response).to have_http_status(:ok)
      data = response.parsed_body["data"]["flag"]
      expect(data["key"]).to eq(flag.key)
      expect(data["enabled"]).to be true
      expect(data["description"]).to eq(flag.description)
      expect(data["id"]).to be_present
    end
  end

  describe "query: evaluateFlag" do
    it "returns enabled: false and flag_not_found: true when flag does not exist" do
      graphql_query(<<~GQL)
        query { evaluateFlag(key: "missing") { enabled flagNotFound } }
      GQL
      expect(response).to have_http_status(:ok)
      data = response.parsed_body["data"]["evaluateFlag"]
      expect(data["enabled"]).to be false
      expect(data["flagNotFound"]).to be true
    end

    it "returns enabled state and flag_not_found: false when flag exists" do
      Flag.create!(key: "on_flag", enabled: true)
      Flag.create!(key: "off_flag", enabled: false)

      graphql_query(<<~GQL)
        query { evaluateFlag(key: "on_flag") { enabled flagNotFound } }
      GQL
      expect(response).to have_http_status(:ok)
      on_data = response.parsed_body["data"]["evaluateFlag"]
      expect(on_data["enabled"]).to be true
      expect(on_data["flagNotFound"]).to be false

      graphql_query(<<~GQL)
        query { evaluateFlag(key: "off_flag") { enabled flagNotFound } }
      GQL
      off_data = response.parsed_body["data"]["evaluateFlag"]
      expect(off_data["enabled"]).to be false
      expect(off_data["flagNotFound"]).to be false
    end
  end

  describe "mutation: createFlag" do
    it "creates a flag with default enabled: false" do
      graphql_query(<<~GQL)
        mutation { createFlag(input: { key: "new_flag" }) {
          flag { key enabled description }
          errors
        } }
      GQL
      expect(response).to have_http_status(:ok)
      data = response.parsed_body["data"]["createFlag"]
      expect(data["errors"]).to eq([])
      expect(data["flag"]["key"]).to eq("new_flag")
      expect(data["flag"]["enabled"]).to be false
      expect(data["flag"]["description"]).to be_nil
      expect(Flag.find_by(key: "new_flag")).to be_present
    end

    it "creates a flag with enabled and description" do
      graphql_query(<<~GQL)
        mutation {
          createFlag(input: { key: "enabled_flag", enabled: true, description: "Turned on" }) {
            flag { key enabled description }
            errors
          }
        }
      GQL
      expect(response).to have_http_status(:ok)
      data = response.parsed_body["data"]["createFlag"]
      expect(data["errors"]).to eq([])
      expect(data["flag"]["enabled"]).to be true
      expect(data["flag"]["description"]).to eq("Turned on")
    end

    it "returns validation errors when key is duplicate" do
      Flag.create!(key: "taken", enabled: false)
      graphql_query(<<~GQL)
        mutation { createFlag(input: { key: "taken" }) { flag { id } errors } }
      GQL
      expect(response).to have_http_status(:ok)
      data = response.parsed_body["data"]["createFlag"]
      expect(data["flag"]).to be_nil
      expect(data["errors"]).to include("Key has already been taken")
    end
  end

  describe "mutation: updateFlag" do
    it "updates enabled state" do
      Flag.create!(key: "toggle_me", enabled: false)
      graphql_query(<<~GQL)
        mutation { updateFlag(input: { key: "toggle_me", enabled: true }) {
          flag { key enabled }
          errors
        } }
      GQL
      expect(response).to have_http_status(:ok)
      data = response.parsed_body["data"]["updateFlag"]
      expect(data["errors"]).to eq([])
      expect(data["flag"]["enabled"]).to be true
      expect(Flag.find_by(key: "toggle_me").enabled).to be true
    end

    it "returns errors when flag not found" do
      graphql_query(<<~GQL)
        mutation { updateFlag(input: { key: "nonexistent", enabled: true }) {
          flag { id }
          errors
        } }
      GQL
      expect(response).to have_http_status(:ok)
      data = response.parsed_body["data"]["updateFlag"]
      expect(data["flag"]).to be_nil
      expect(data["errors"]).to include("Flag not found: nonexistent")
    end
  end
end
