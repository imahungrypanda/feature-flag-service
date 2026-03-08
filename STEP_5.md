# Step 5: REST Evaluation Endpoint & API Versioning

## Current State

The only API surface is a GraphQL endpoint at `POST /graphql`. GraphQL is excellent for management operations (create, update, audit), but it is heavyweight for a hot-path use case: an SDK calling "is this flag on for this user?" from inside a web request handler. A lightweight, cacheable REST endpoint for flag evaluation lowers the barrier to adoption and enables HTTP-level caching (CDN, Varnish, `Fastly-Surrogate-Key`).

## Goal

1. Add a **REST evaluation endpoint** at `GET /v1/flags/:key/evaluate` that is purpose-built for the hot path
2. Introduce **API versioning** (`/v1/`) so both the REST and GraphQL surfaces can evolve independently
3. Lay the groundwork for a **lightweight Ruby SDK** that wraps the REST endpoint

## Implementation Approach

### 1. Routes: versioned namespace

```ruby
# config/routes.rb
Rails.application.routes.draw do
  namespace :v1 do
    resources :flags, param: :key, only: [] do
      member do
        get :evaluate
      end
    end
  end

  post "/graphql", to: "graphql#execute"
end
```

This produces `GET /v1/flags/:key/evaluate` without breaking the existing `/graphql` route.

### 2. Controller: `V1::FlagsController#evaluate`

```ruby
# app/controllers/v1/flags_controller.rb
module V1
  class FlagsController < ApplicationController
    before_action :authenticate_token!

    def evaluate
      flag = Flag.cached_find_by_key(params[:key])

      if flag.nil?
        render json: { enabled: false, flag_not_found: true }, status: :ok
        return
      end

      enabled = flag.evaluate(
        user_id:    params[:user_id],
        attributes: JSON.parse(params[:attributes] || "{}")
      )

      render json: {
        enabled:        enabled,
        flag_not_found: false,
        key:            flag.key
      }, status: :ok
    rescue JSON::ParserError
      render json: { error: "attributes must be valid JSON" }, status: :unprocessable_entity
    end

    private

    def authenticate_token!
      # reuse same logic as GraphqlController
    end
  end
end
```

Query parameters: `user_id` (optional string), `attributes` (optional JSON string).

Example request:
```
GET /v1/flags/new-checkout/evaluate?user_id=u_123&attributes={"plan":"enterprise"}
Authorization: Bearer YOUR_TOKEN
```

Example response:
```json
{ "enabled": true, "flag_not_found": false, "key": "new-checkout" }
```

### 3. Authentication: extract to `ApplicationController`

The Bearer token authentication logic is currently duplicated in `GraphqlController`. Move it to `ApplicationController` as a shared `authenticate_token!` concern so both controllers use the same implementation:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  private

  def authenticate_token!
    token = request.headers["Authorization"]&.delete_prefix("Bearer ")
    expected = ENV["FEATURE_FLAG_API_TOKEN"] || Rails.application.credentials.feature_flag_api_token
    unless token.present? && ActiveSupport::SecurityUtils.secure_compare(token, expected.to_s)
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end
```

### 4. HTTP caching headers

Add `Cache-Control` and `ETag` headers to the REST response so upstream caches (CDN, proxy) can cache evaluation results:

```ruby
response.set_header("Cache-Control", "private, max-age=30")
response.set_header("ETag", flag.cache_key_with_version)
```

Use `stale?` / `fresh_when` Rails helpers to return `304 Not Modified` when the flag has not changed since the client's cached copy.

### 5. SDK sketch: `FeatureFlagClient` Ruby gem (separate repo)

Document the interface for a minimal Ruby client that wraps the REST endpoint:

```ruby
client = FeatureFlagClient.new(
  base_url: "https://flags.example.com",
  token:    ENV["FEATURE_FLAG_API_TOKEN"]
)

client.enabled?("new-checkout", user_id: current_user.id, attributes: { plan: current_user.plan })
# => true | false
```

The client should:
- Cache responses in-process for a short TTL (matching the server's `Cache-Control` max-age)
- Return `false` for any network error (fail-safe default)
- Be thread-safe

The SDK itself is a separate deliverable, but defining its interface here ensures the REST API is designed with the right ergonomics from the start.

## Tests to Add

- `GET /v1/flags/:key/evaluate` returns `200` with correct JSON for enabled/disabled flags
- Returns `{ enabled: false, flag_not_found: true }` for unknown keys
- Returns `401` for missing/invalid token
- `user_id` and `attributes` params are passed through to `flag.evaluate`
- Malformed `attributes` JSON returns `422`
- `304 Not Modified` returned when ETag matches
- Authentication logic is not duplicated (single definition in `ApplicationController`)

## Expected Outcome

Client applications can evaluate flags with a simple `GET` request using any HTTP client, without understanding GraphQL. The endpoint is safe to call on every web request — it is fast (backed by the cache from Step 4), semantically correct (`GET` for a read), and HTTP-cacheable at the infrastructure level. The extracted authentication logic eliminates code duplication. The versioned URL structure (`/v1/`) allows future breaking changes without disrupting existing clients.
