# CLAUDE.md — `koala` (LFM fork)

> **One-line purpose:** LFM's fork of the popular `arsduo/koala` Ruby Facebook Graph API gem (frozen at upstream 2.4.0rc1, ~2016), with one LFM addition: a `CountsAPIMethods` module + CLI for Facebook Topic-Insights and Hashtag-Counts.

## 1. Repo identity

- **Repo type:** `library` (Ruby gem; LFM fork of OSS upstream).
- **Primary language(s):** Ruby. Upstream supports MRI 1.9.3 / 2.0 / 2.1 / 2.2 + JRuby (per `.travis.yml`); the gemspec doesn't enforce a minimum. The repo predates Ruby 3 and was last touched in 2016.
- **Primary framework(s):** Ruby gem (Faraday-based HTTP), with optional Typhoeus for parallel requests. Uses RSpec 3.4 + VCR + WebMock for tests.
- **Lifecycle status:** `maintenance-only` — frozen at upstream `v2.4.0rc1` since April 2016. **Single LFM commit** ever (`7226254`, by Anthony Battaglia). Upstream `arsduo/koala` is now at v3.4+; this fork is **9+ years stale**.
- **Repo URL:** https://github.com/ListenFirstMedia/koala (default branch: `master`).
- **On-call / owners:** _<TODO: confirm — the only LFM commit is by `Anthony Battaglia <anthony.battaglia@listenfirstmedia.com>` (2016-04-27).>_
- **Slack channel:** _<TODO>_
- **Confluence / docs root:** Upstream wiki at https://github.com/arsduo/koala/wiki; in-repo `readme.md` is upstream's (15 KB, comprehensive).

## 2. Why this repo exists

LFM forked `arsduo/koala` (the de-facto Ruby Facebook SDK) to add a **`CountsAPIMethods` module** (`lib/koala/api/counts_api.rb`) implementing two LFM-specific Facebook endpoints:

1. **`topic_insights(topic_ids, args, opts)`** — Calls Facebook's Topic Insights API in chunks (max 21,600 seconds per request per the API limit), aggregating counts and breakdowns across the full requested time window. Used by `cms`-side admin tools to populate brand-related social analytics.
2. **`hashtag_counts(hashtags, args, opts)`** — Wraps Facebook's hashtag counter, normalizes hashtag inputs (strips leading `#`, lowercases), and returns per-hashtag counts.
3. **`topic_counts(ids, args)`** — Convenience method that takes mixed `[hashtags, topic_ids]` and dispatches to the right method.

Plus a `bin/topic-api` CLI for ad-hoc topic-count queries from the command line.

The fork exists because, at the time, upstream had no first-class support for these endpoints, and LFM needed them in production. The main commit message _"pass through request options args from counts methods to graph api calls"_ refers to a specific bugfix on top of the initial fork — the LFM-only counts methods now correctly forward Faraday `opts` through to the underlying Graph API call.

It's a separate repo because the additions are LFM business logic, not upstream-mergeable concerns. The fork has stagnated because Facebook deprecated/removed both endpoints (Topic Insights was rolled into the broader Topic Search; hashtag_counter was sunset) — meaning the LFM-specific code may no longer work against current Facebook API versions.

## 3. Where it sits in the platform

A pure Ruby gem.

- **Upstream services this repo calls** (runtime HTTP/RPC, when used):
  - **Facebook Graph API** — base URL `https://graph.facebook.com/<api_version>/...` (configurable via `Koala.config.api_version`).
  - **Facebook REST API** (deprecated upstream; still in the gem). Base URL `https://api.facebook.com/...`.
  - HTTP via Faraday (Net::HTTP by default; Typhoeus for parallel via `Faraday::Adapter::Typhoeus`).
- **Downstream consumers** (LFM repos that bundle THIS as a gem; from `dependency_graph.json`):
  - `cms` — pinned to `git: 'https://github.com/ListenFirstMedia/koala.git'` (no branch — uses default `master`). Used by `cms` for Facebook-side admin lookups (brand search-term validation, topic-id resolution, hashtag-counter UIs).
  - `lfm-accounts` consumes upstream `koala ~> 3.4.0` from rubygems (NOT this LFM fork). The naming similarity is misleading.
- **Library deps** (compile-time, from `koala.gemspec`):
  - Runtime: `multi_json >= 1.3.0`, `faraday`, `addressable`.
  - DevDeps (per `Gemfile`): `rake`, `typhoeus` (unless JRuby), `rspec ~> 3.4`, `vcr`, `webmock`, `codeclimate-test-reporter`, `yard`, `byebug` / `debugger`.

> Phase 1 dependency map for this repo: `~/Documents/claude-github/phase1/koala.json`.

## 4. HTTP / RPC interface

_N/A — this is a Ruby gem; it exposes no HTTP routes._

It provides the upstream `Koala::Facebook::API` class plus the LFM-only `Koala::Facebook::CountsAPIMethods` mixin.

## 5. APIs this repo CONSUMES

| Target service | Purpose | How it's configured | Failure mode |
|---|---|---|---|
| **Facebook Graph API** | All `Koala::Facebook::API#*` calls (`get_object`, `get_connections`, `put_object`, `delete_object`, batch requests, etc.) | `Koala.config.api_version` (default unspecified — uses Facebook's default-version rules); `Koala::HTTPService::DEFAULT_SERVERS` for host overrides | `Koala::Facebook::APIError` (subclasses for ClientError, ServerError, AuthenticationError, etc.) |
| **Facebook REST API** | Legacy `rest_call` methods (deprecated upstream) | Same | Same |
| **Facebook Topic Insights API** (LFM-specific via `CountsAPIMethods`) | `topic_insights(topic_ids, args, opts)` — chunked over 21600-second windows | Caller passes `args[:mentions_since]`, `args[:mentions_until]`, `args[:breakdown_by]` | Same |
| **Facebook Hashtag Counter API** (LFM-specific via `CountsAPIMethods`) | `hashtag_counts(hashtags, args, opts)` | Same | Same |

## 6. Tech stack details

- **Runtime versions:**
  - Ruby — `.travis.yml` matrix: 1.9.3 / 2.0 / 2.1 / 2.2 (and JRuby 19-mode). The gemspec sets no `required_ruby_version`. **Real-world usage is constrained by the consumer (`cms` runs Ruby 3.2.2)** — koala on Ruby 3.2 has known minor bugs upstream, and this fork hasn't been tested against modern Ruby.
- **Package manager(s):** Bundler (`Gemfile`, `koala.gemspec`).
- **Build/test commands:**
  - Install: `bundle install`
  - Tests (mocked): `bundle exec rspec` (default RSpec via `.rspec` config: `--color --order rand`)
  - Tests (live, against real Facebook): _<TODO: upstream's `spec/koala_spec_without_mocks.rb` requires real FB credentials in a `facebook_data.yml` fixture; LFM doesn't appear to run this.>_
  - Docs: `bundle exec rake yard` → `doc/yard/`
  - CLI: `bin/topic-api -t '#mlb' -s '2026-04-30T00:00:00' -u '2026-04-30T23:59:59'` (LFM-specific; requires a Facebook access token in a config file)
- **Notable internal LFM gems / packages bundled here:** None (this IS one of the LFM-internal forks).
- **Why we forked:** To add `CountsAPIMethods` (Topic Insights + Hashtag Counts) and a `bin/topic-api` CLI. Upstream had no equivalent.

## 7. Local development

### 7.1 Required services

- For mocked RSpec runs: nothing. WebMock + VCR replay recorded HTTP interactions.
- For live tests / `bin/topic-api`: a Facebook access token with the right permissions (Topic Insights API access has historically required app-level allow-listing from Facebook).

### 7.2 Required env vars

| Name | Purpose | Example | Where it's read |
|---|---|---|---|
| (none in the gem at runtime) | The gem accepts an `access_token` argument to `Koala::Facebook::API.new(...)` | — | Caller provides |
| `FB_ACCESS_TOKEN` (LFM convention) | Used by `bin/topic-api` if its option-parser is invoked | _<TODO: confirm — `bin/topic-api` likely accepts `-a/--access-token` flag instead>_ | `bin/topic-api` |

### 7.3 First-time setup

```
1. asdf install ruby 1.9.3   # or any of the .travis.yml-supported versions
   # OR force a modern Ruby and accept potential bug surface:
   asdf install ruby 3.2.2
2. cd koala
3. bundle install            # may need bundler 1.x for old gem versions; bundler 2.x usually works
4. bundle exec rspec         # mocked tests
```

To use locally during dev of `cms`:

```
# In cms/Gemfile, replace the :git line with :path:
gem 'koala', '~> 2.0', require: false, path: '../koala'
```

## 8. Tests

- **How tests are organized:** RSpec under `spec/`. `spec/koala_spec_helper.rb` is the entry point. Subdirs: `spec/cases/api/`, `spec/cases/realtime_updates/`, `spec/cases/uploadable_io/`, etc. Tests can be run mocked (default) or live against real Facebook (`spec/koala_spec_without_mocks.rb`).
- **How to run a single test:** `bundle exec rspec spec/cases/api/api_spec.rb -e 'description fragment'`
- **CI green criteria:** `.travis.yml` was the upstream CI config (Travis CI). Travis CI shut down free open-source builds in 2021; the config no longer runs anywhere. **There is NO active CI for this LFM fork.**
- **Coverage target / current %:** Upstream uploads coverage to CodeClimate (see `.travis.yml`'s `addons.code_climate.repo_token`). The LFM fork inherited this config but the corresponding CodeClimate repo is upstream's, not LFM's. _<TODO: disable or rotate the inherited CodeClimate token — see §13.>_
- **Mocks vs. real services:** WebMock + VCR by default. Live testing requires real Facebook credentials.

## 9. Deployment

- **Where it deploys:** Nowhere directly. This is a gem. "Deployment" = pushing commits to LFM `master` and having `cms` `bundle update` to the new SHA on next deploy.
- **How a deploy happens:** Push to `master`. `cms`'s Gemfile pins to the LFM-fork's `master` branch via git URL — pulls automatically on next `bundle install`/`bundle update`.
- **Branching model:** `master` (default) is the only LFM-active branch. The 25+ other branches visible in the GitHub repo are all upstream's (`arsduo/koala`) branches that came along when LFM forked.
- **Infra-as-code:** N/A.
- **Rollback:** Pin the consumer (`cms`) back to an older SHA in its Gemfile.
- **Health-check endpoint:** N/A.

## 10. Configuration & secrets

- **Secret store:** N/A (consumers handle their Facebook access tokens via their own env / Rails encrypted credentials).
- **How config is loaded at runtime:** `Koala.configure { |c| c.api_version = 'v15.0' }` (and similar). All config is consumer-driven.
- **Where to find example values:** Upstream `readme.md` has copious examples.
- **Feature flags:** N/A.

## 11. Data stores & state

- **No data stores accessed.**
- **In-process state:**
  - `Koala.config` — module-level `OpenStruct` of HTTPService defaults (server URLs, api_version).
  - `Koala.http_service` — module-level reference to the HTTPService class (swappable for testing via `Koala.http_service =`).
  - The default HTTPService maintains no per-request state.

## 12. File / directory map

```
koala/
├── readme.md                    — upstream README (15 KB; comprehensive Facebook usage examples)
├── CLAUDE.md                    — this file
├── changelog.md                 — upstream changelog through v2.4.0; LFM additions not separately logged
├── code_of_conduct.md           — upstream stock
├── LICENSE                      — MIT (Alex Koppel)
├── Gemfile                      — RSpec, VCR, WebMock, etc. dev deps
├── Manifest                     — old-style file manifest (predates `git ls-files`)
├── Rakefile                     — test, yard
├── koala.gemspec                — name `koala`, author `Alex Koppel`, homepage `arsduo/koala`. NO LFM identification in metadata.
├── .autotest                    — autotest config
├── .gitignore, .rspec, .yardopts
├── .travis.yml                  — ⚠️ upstream Travis config; line 17 contains a CodeClimate repo_token (see §13). Travis CI no longer runs this.
├── Guardfile                    — guard config for spec watcher
├── bin/
│   ├── console                  — `irb` with koala loaded
│   └── topic-api                — LFM-specific CLI for topic-counts queries
├── lib/
│   ├── koala.rb                 — main module: requires submodules, exposes `Koala.configure`, `Koala.http_service`
│   └── koala/
│       ├── api.rb               — `Koala::Facebook::API` class (includes GraphAPIMethods, RestAPIMethods, CountsAPIMethods)
│       ├── api/
│       │   ├── graph_api.rb     — Graph API (upstream)
│       │   ├── rest_api.rb      — Legacy REST API (upstream, deprecated)
│       │   ├── counts_api.rb    — ⚠️ LFM-only addition: topic_counts/topic_insights/hashtag_counts
│       │   ├── graph_collection.rb — Pagination helper (upstream)
│       │   ├── graph_batch_api.rb — Batch request handling (upstream)
│       │   ├── graph_error_checker.rb — Error response parsing (upstream)
│       │   └── batch_operation.rb
│       ├── errors.rb            — Error class hierarchy
│       ├── http_service.rb      — Faraday-based HTTP wrapper
│       ├── http_service/
│       │   ├── multipart_request.rb
│       │   ├── response.rb
│       │   └── uploadable_io.rb
│       ├── oauth.rb             — OAuth flows + signed-request parsing
│       ├── realtime_updates.rb  — Facebook real-time updates subscription handling
│       ├── test_users.rb        — Facebook test-user creation
│       ├── utils.rb             — Misc helpers (incl. `is_hashtag?` used by counts_api)
│       └── version.rb           — `Koala::VERSION = "2.4.0rc1"`
├── spec/                        — RSpec tests (upstream layout). Subdirs for api, oauth, realtime_updates, test_users, http_services. Plus mock_http_service.rb, koala_spec_without_mocks.rb (for live testing).
└── autotest/discover.rb         — autotest discovery shim
```

Not a monorepo — single gem at root.

## 13. Conventions & gotchas

### ⚠️ Committed credentials (newly identified during this deep read)

**`.travis.yml` line 17** contains a hardcoded CodeClimate repo_token:

```yaml
addons:
  code_climate:
    repo_token: 7af99d9225b4c14640f9ec3cb2e24d2f7103ac49417b0bd989188fb6c25f2909
```

64-hex-char value, real CodeClimate token format. **NEW finding** — added to `~/Documents/claude-github/phase1/SECURITY_FINDINGS.md` as F59.

Severity: 🟡 Medium. The token authenticates coverage uploads to CodeClimate. Even if the corresponding CodeClimate repo is upstream's `arsduo/koala` (not LFM's), the token in this file should still be removed because:
1. Travis CI no longer runs this `.travis.yml` (Travis dropped free OSS builds in 2021), so it's dead config.
2. Leaving a live-format token in source-control sets a bad precedent.
3. If upstream rotates the token, this committed copy becomes a "spoofable identity" on a dead pipeline — low risk but unnecessary.

Remediation: delete the `addons.code_climate` block (or the whole `.travis.yml` since it's dead config), and let upstream handle their own CI/coverage independently.

### General koala conventions

- **This is a 9-year-old fork at upstream `v2.4.0rc1`.** Upstream is at v3.4+. Major Facebook Graph API breaking changes have occurred; the LFM-specific `CountsAPIMethods` (Topic Insights + Hashtag Counter) endpoints **may no longer work** against current Facebook API versions because Facebook deprecated/removed them. _<TODO: confirm whether `cms`'s use of `topic_insights` / `hashtag_counts` is still functional against today's Facebook API, or whether this code is dead-pull dependency.>_
- **`koala.gemspec` author + homepage point at upstream**: `gem.authors = ["Alex Koppel"]`, `gem.email = "alex@alexkoppel.com"`, `gem.homepage = "http://github.com/arsduo/koala"`. This is correct (MIT attribution); don't change.
- **The `.travis.yml` is dead.** Travis CI sunset free open-source builds in 2021. The `.travis.yml` here doesn't run anywhere.
- **No active CI.** No `.github/workflows/`. Tests are not run automatically on any LFM PR.
- **The 25+ extra branches visible on the GitHub repo are all upstream's** (vcr, rdoc, debug_token, dimelo-paging-version, etc.), imported when LFM forked. They aren't actively merged forward; treat them as historical.
- **The single LFM commit (`7226254`)** is misleadingly titled — the commit message describes the latest tweak (passing `opts` through), but the actual diff includes the initial repo creation (the entire upstream tree at that point in time). The "initial-and-final commit" pattern.
- **`CountsAPIMethods` is LFM-only.** When upstream is consulted for a Facebook-API question, don't expect to find topic_insights / hashtag_counts in their docs.
- **`Koala::Facebook::APIError`** subclasses are the right exception base — don't rescue from `StandardError` casually.
- **Faraday adapter selection:** by default Net::HTTP; if Typhoeus is available, Koala uses it for parallel requests. The `cms` Gemfile doesn't include Typhoeus, so all requests are serial Net::HTTP.
- **`require: false`** in `cms`'s `Gemfile` — koala is loaded on-demand by the code that uses it, not at app boot. Useful given how stale the gem is — it doesn't slow boot if unused.

## 14. Common tasks (cookbook)

- **Run tests:** `bundle exec rspec`
- **Run a single spec:** `bundle exec rspec spec/cases/api/api_spec.rb -e 'topic_counts'`
- **Build the gem:** `gem build koala.gemspec` (only needed if publishing — LFM consumes via git URL, not rubygems)
- **Generate YARD docs:** `bundle exec rake yard`
- **Use the topic-api CLI:** `bin/topic-api --help` (exact flags TBD; see `bin/topic-api`)
- **Sync from upstream `arsduo/koala`** (only useful if upstream eventually re-adds Topic Insights / Hashtag Counter, which is unlikely):
  1. `git remote add upstream https://github.com/arsduo/koala.git`
  2. `git fetch upstream`
  3. `git merge upstream/main` — resolve enormous conflicts (9 years of divergence).
  4. Verify `lib/koala/api/counts_api.rb` and `bin/topic-api` survived.
  5. Verify `cms`'s Facebook integration tests still pass.
- **Bump consumer pin:** in `cms`, `bundle update koala` — pulls latest `master` SHA.
- **Drop the fork** (likely the right long-term move, given Facebook's deprecation of these endpoints):
  1. Verify `cms` no longer needs `topic_insights` / `hashtag_counts` (or rewrite using current Facebook APIs).
  2. Switch `cms`'s Gemfile from `git: ...` URL to a regular `gem 'koala', '~> 3.4'` rubygems pin.
  3. Archive this LFM repo.

## 15. Known issues / migrations in flight

- **9-year-old fork; upstream is far ahead.** Last LFM activity: 2016-04-27. Upstream's v3.x has significantly evolved Facebook API support (newer Graph API versions, async batch, etc.). The fork is increasingly a liability.
- **Facebook deprecated/removed both endpoints** the LFM fork was built around (Topic Insights, Hashtag Counter). The `CountsAPIMethods` code may be making calls that always 404 / return errors at this point. _<TODO: smoke-test in a current `cms` deploy.>_
- **Travis CI is dead.** `.travis.yml` doesn't run. No replacement CI was set up.
- **CodeClimate token in `.travis.yml`** should be removed (see §13).
- **Tests have likely never run on Ruby 3+.** The `.travis.yml` matrix tops out at Ruby 2.2; the consumer (`cms`) runs Ruby 3.2. If you run `bundle exec rspec` on a modern Ruby, expect deprecation warnings and possibly failures.
- **Branches inherited from upstream** (vcr, rdoc, integration, etc.) are noise. _<TODO: prune them.>_
- **Eventual goal: drop the fork.** Either contribute the Topic Insights / Hashtag Counter logic upstream (unlikely to be accepted given Facebook deprecation), or rewrite the LFM code paths in `cms` to use upstream koala 3.x or current Facebook API patterns directly.

## 16. Glossary

| Term | What it means here |
|---|---|
| `Koala::Facebook::API` | The main client class — instantiated with an access token + optional app secret. |
| `CountsAPIMethods` | LFM-only mixin (`lib/koala/api/counts_api.rb`) providing `topic_counts`, `topic_insights`, `hashtag_counts`. |
| `topic_insights(topic_ids, args, opts)` | LFM Facebook Topic Insights wrapper that handles 21600-second time-window chunking. |
| `hashtag_counts(hashtags, args, opts)` | LFM Hashtag Counter wrapper with input normalization (strip leading `#`, lowercase). |
| `bin/topic-api` | LFM CLI for ad-hoc topic-count queries. |
| `breakdown_by` | LFM-specific arg passed to `topic_insights` for dimension-breakdown queries (gender, age_range, etc.). |
| `appsecret_proof` | Upstream Koala feature — HMAC-signed access token for additional Facebook security. |
| `realtime_updates` | Upstream Koala feature for Facebook's webhook subscriptions. |
| `test_users` | Upstream Koala feature for creating Facebook test users via the Graph API. |

## 17. AI agent guidance (do's and don'ts)

**Do:**

- Treat this as a **frozen vendored fork**. Don't refactor; don't bump deps; don't rewrite for Ruby 3.
- If you must touch the gem, scope to the LFM-only `lib/koala/api/counts_api.rb` and `bin/topic-api`. Leave upstream files alone.
- Before changing anything, confirm with the `cms` team that `topic_insights` / `hashtag_counts` are still being used in production. If not, archive this repo.
- Keep `koala.gemspec` author/homepage at upstream — MIT attribution.
- Remove the dead `.travis.yml` entirely (or at minimum the CodeClimate `repo_token` line).
- When `cms` finally drops this dependency, archive the GitHub repo.

**Don't:**

- Don't bump dependencies. The point of the fork is stability, not currency.
- Don't try to merge upstream `arsduo/koala`. 9 years of divergence + Facebook API churn = enormous conflict resolution.
- Don't push to GitHub Actions / set up CI here without first verifying the gem's tests can even pass on a modern Ruby.
- Don't add new Facebook-API features here. Either upstream them to `arsduo/koala` (better) or write them directly in `cms`.
- Don't try to publish this to rubygems.org. LFM consumes via git URL only; rubygems would conflict with upstream's `koala` package name.
- Don't commit credentials — see §13 / SECURITY_FINDINGS.md F59.
- Don't trust the upstream `readme.md`'s installation instructions — they describe rubygems install, but `cms` consumes via git URL.

## 18. Drift markers

- **Last verified against code:** 2026-04-30 by `Claude` (Phase 2 deep read).
- **What I read in full:**
  - Repo root: `readme.md` (head), `changelog.md` (head), `koala.gemspec`, `Gemfile`, `Rakefile`, `Manifest`, `LICENSE`, `.travis.yml`, `.autotest`, `.rspec`, `.yardopts`
  - `lib/koala.rb`, `lib/koala/api.rb` (head), `lib/koala/api/counts_api.rb` (full — the LFM-specific code), `lib/koala/version.rb`
  - Full directory listing of `lib/`, `bin/`, `spec/`
  - `bin/topic-api` (head)
  - `git log` of master + branch listing (verified single LFM commit; 25+ inherited upstream branches)
  - Confirmed `7226254` is the only commit on master
- **What I did NOT read in full:**
  - 44 `.rb` files in upstream `lib/` (graph_api, rest_api, oauth, realtime_updates, test_users, http_service, errors, utils, etc.) — these are upstream-stock and well-documented at https://github.com/arsduo/koala.
  - All `spec/` test files.
  - Full `bin/topic-api` body (only head).
  - `changelog.md` past head (it's upstream's; LFM doesn't add to it).
- **Sections most likely to drift first:** §15 (whether the Facebook endpoints still work), §17 (the "drop the fork" recommendation depends on `cms`'s actual usage).
- **Auto-checks (when wired up):**
  - [ ] `bundle exec rspec` green on the consumer's Ruby version
  - [ ] `lib/koala/api/counts_api.rb` and `bin/topic-api` (the LFM-specific code) are still present
  - [ ] no committed credentials in tracked files (gitleaks / trufflehog scan in CI)

---
