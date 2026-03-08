# Step 4: Caching Layer for Flag Evaluation

## Current State

Every `evaluateFlag` call hits the database. Feature flag checks are among the most read-heavy operations in any system — a high-traffic application may evaluate dozens of flags per request, potentially thousands of times per second. A single flag evaluation should be sub-millisecond; a database round-trip cannot achieve this at scale.

## Goal

Add a transparent caching layer so that:
1. Flag state is served from memory (Rails cache) on the hot path
2. Cache is invalidated automatically when a flag is mutated
3. The cache is observable (hits/misses can be measured)

## Implementation Approach

### 1. Cache store: Solid Cache (already in Gemfile)

The project already includes `solid_cache`. Configure it as the Rails cache store:

```ruby
# config/environments/production.rb
config.cache_store = :solid_cache_store
```

For development/test, use `:memory_store` to avoid external dependencies.

### 2. Model: `Flag.cached_find_by_key(key)`

Add a class method that wraps the database lookup with Rails cache:

```ruby
CACHE_TTL = ENV.fetch("FLAG_CACHE_TTL_SECONDS", 60).to_i.seconds

def self.cached_find_by_key(key)
  Rails.cache.fetch(cache_key_for(key), expires_in: CACHE_TTL) do
    active.find_by(key: key)
  end
end

def self.cache_key_for(key)
  "flags/#{key}"
end
```

A short TTL (60 seconds default) provides a safety net: even if a cache invalidation is missed, the flag will self-heal within the TTL window.

### 3. Cache invalidation: `after_commit` callback

Invalidate the cache on every committed write (create, update, archive):

```ruby
after_commit :invalidate_cache

private

def invalidate_cache
  Rails.cache.delete(self.class.cache_key_for(key))
end
```

`after_commit` is used (not `after_save`) to avoid invalidating the cache before the transaction is visible to other database connections.

### 4. GraphQL resolver: use `cached_find_by_key`

Update `evaluateFlag` and `flag` resolvers in `QueryType`:

```ruby
# Before
flag = Flag.active.find_by(key: key)

# After
flag = Flag.cached_find_by_key(key)
```

No other changes needed in the GraphQL layer.

### 5. Cache warming: Rake task

Add an optional warm-up task to pre-populate the cache after a deploy (useful when the cache store is fresh after a restart):

```ruby
# lib/tasks/cache.rake
task warm_flags_cache: :environment do
  Flag.active.find_each do |flag|
    Rails.cache.write(Flag.cache_key_for(flag.key), flag, expires_in: Flag::CACHE_TTL)
  end
  puts "Warmed cache for #{Flag.active.count} flags"
end
```

### 6. Observability: log cache hits/misses

Instrument the cache layer with ActiveSupport notifications so cache hit rate appears in logs and future APM tooling:

```ruby
def self.cached_find_by_key(key)
  cache_hit = true
  result = Rails.cache.fetch(cache_key_for(key), expires_in: CACHE_TTL) do
    cache_hit = false
    active.find_by(key: key)
  end
  Rails.logger.debug("[FeatureFlag] cache #{cache_hit ? 'HIT' : 'MISS'} for key=#{key}")
  result
end
```

## Tests to Add

- `Flag.cached_find_by_key` returns a flag on first call (cache miss → DB)
- Second call for same key does not hit DB (mock `Flag.active` to raise on second call, or use `expect(...).to receive(...).once`)
- Updating a flag invalidates its cache entry
- Archiving a flag invalidates its cache entry
- `evaluateFlag` resolver uses cached lookup (integration test with cache assertions)
- TTL configuration is respected (test with frozen time)

## Expected Outcome

Flag evaluations are served from in-process or shared memory on the hot path, reducing p99 latency for `evaluateFlag` from ~5ms (DB) to <1ms. The database load from flag reads drops by >95% under steady-state traffic. Cache staleness is bounded to the TTL window, and explicit invalidation ensures fresh data after every flag change.
