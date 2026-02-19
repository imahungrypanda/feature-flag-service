# Feature Flag Service

Rails API that exposes feature flag create, evaluate, and update operations via a single GraphQL endpoint. All operations require a Bearer token.

## Requirements

- Ruby 3.3+
- PostgreSQL
- Bundler

## Setup

1. **Install dependencies**

   ```bash
   bundle install
   ```

2. **Configure the database**

   Ensure PostgreSQL is running. Create and migrate:

   ```bash
   rails db:create
   rails db:migrate
   ```

3. **Configure the API token**

   Every request must include a valid Bearer token. Set it in one of these ways:

   - **Environment variable (recommended for local dev):**

     ```bash
     export FEATURE_FLAG_API_TOKEN=your-secret-token
     ```

   - **Rails credentials:**

     ```bash
     rails credentials:edit
     # Add under the environment key, e.g.:
     # feature_flag_api_token: your-secret-token
     ```

   Do not commit the token. Use HTTPS in production.

4. **Start the server**

   ```bash
   rails server
   ```

   The GraphQL endpoint is `POST http://localhost:3000/graphql`.

## API overview

- **Authentication:** Send the token in the `Authorization` header: `Authorization: Bearer YOUR_TOKEN`. Requests without a valid token receive `401 Unauthorized` with a non-revealing message.
- **Missing flags:** When you evaluate a key that does not exist, the API returns `enabled: false` and `flagNotFound: true` so callers can degrade gracefully. No 500 is returned for unknown keys.

## Example operations

Use any HTTP client (e.g. `curl`) or a GraphQL client. All requests must be `POST` with `Content-Type: application/json` and the `Authorization` header.

### Create a flag

```bash
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "query": "mutation { createFlag(input: { key: \"my_feature\", enabled: true, description: \"Optional description\" }) { flag { key enabled description } errors } }"
  }'
```

Example response:

```json
{
  "data": {
    "createFlag": {
      "flag": {
        "key": "my_feature",
        "enabled": true,
        "description": "Optional description"
      },
      "errors": []
    }
  }
}
```

### Evaluate a flag

```bash
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "query": "query { evaluateFlag(key: \"my_feature\") { enabled flagNotFound } }"
  }'
```

With optional context (accepted; not used for routing in MVP):

```bash
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "query": "query { evaluateFlag(key: \"my_feature\", userId: \"user-123\", attributes: { \"plan\": \"pro\" }) { enabled flagNotFound } }"
  }'
```

Example response when the flag exists:

```json
{
  "data": {
    "evaluateFlag": {
      "enabled": true,
      "flagNotFound": false
    }
  }
}
```

When the flag does not exist:

```json
{
  "data": {
    "evaluateFlag": {
      "enabled": false,
      "flagNotFound": true
    }
  }
}
```

### Update (toggle) a flag

```bash
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "query": "mutation { updateFlag(input: { key: \"my_feature\", enabled: false }) { flag { key enabled } errors } }"
  }'
```

Example response:

```json
{
  "data": {
    "updateFlag": {
      "flag": {
        "key": "my_feature",
        "enabled": false
      },
      "errors": []
    }
  }
}
```

### Retrieve a flag by key

```bash
curl -X POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "query": "query { flag(key: \"my_feature\") { key enabled description } }"
  }'
```

## Summary

Using this README and the API you can:

1. **Create** a flag: `createFlag(input: { key, enabled?, description? })`
2. **Evaluate** a flag: `evaluateFlag(key:, userId?, attributes?)` → `{ enabled, flagNotFound }`
3. **Toggle** a flag: `updateFlag(input: { key, enabled })`

Missing or invalid keys on evaluate return a deterministic result (`enabled: false`, `flagNotFound: true`) so your app can degrade gracefully.
