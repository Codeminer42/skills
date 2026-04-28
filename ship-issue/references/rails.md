# Rails conventions for ship-issue

Read this when the probe step shows `Gemfile` + Rails. The conventions below match a Rails-Omakase + Codeminer42 house style and align with hire42's `CLAUDE.md`. If the project's own `CLAUDE.md` or `AGENTS.md` contradicts something here, the project file wins — this is the default, not a mandate.

Cite these in the Phase 1 planner brief so the plan respects them, and in Phase 3 reviewer briefs so reviewers know what "consistent with the codebase" means.

## Architecture

- **Service objects** live in `app/services/<domain>/` as POROs with a single public `.call`. Names are verbs: `Candidates::Create`, `Jobs::Publish`, `Applications::Review`. Use them whenever the work spans more than a single ActiveRecord write or has a non-trivial transactional shape.
- **Thin controllers** — receive params, delegate to a service, respond. Stick to the seven RESTful actions; prefer a new resource over a custom action. No `before_action` for resource loading — only for authentication/authorization (`authenticate_user!`). No `after_action`/`around_action`.
- **Strong params always.** Never `permit!`.
- **Models are validations + associations + scopes.** No business logic, no callbacks (`before_*` / `after_*` / `around_*`). The single exception is trivial data normalization with no side effects (`before_validation :strip_whitespace`). Everything else routes through a service.
- **Scopes over class methods** for query logic. Prevent N+1 with `includes`/`preload`/`eager_load` from the start.
- **Views** carry no business logic. Use presenters or ViewComponents.
- **Generators always.** `rails g model|migration|controller|job|mailer` — never hand-write a migration. `rails g scaffold` is too much; don't use it.

## Database

- Use database constraints (NOT NULL, unique indexes, foreign keys). Don't rely on Rails validations alone.
- Migrations are reversible.
- Avoid raw SQL unless necessary; parameterize with `sanitize_sql` or bind vars.

## Testing (RSpec)

- Structure: `describe` > `context` > `it`, always.
- `let`/`let!` only — never instance variables. `let` lazily; `let!` only when the record must exist before the example runs.
- `build_stubbed` when persistence isn't needed.
- FactoryBot with traits, Faker for data, Shoulda Matchers for model specs.
- Test behavior, not implementation.
- Unit specs for services and models. Feature/system specs for critical user flows. Request specs only when there's meaningful HTTP-layer behavior.
- Aim for >95% meaningful coverage — not vanity metrics. Keep specs fast.

## Security

- Never skip `protect_from_forgery` (CSRF protection).
- Strong parameters always; never `permit!`.
- No string interpolation in SQL — parameterized queries only.
- `encrypts` (Rails 7+) for PII fields.
- Rate-limit authentication endpoints and APIs (Rails 8 has `rate_limit` built in — does Rails already provide this? If yes, use it before adding a gem).

## i18n

- All user-facing strings go through `I18n.t`. No hardcoded text in views, mailers, or flash messages.
- Locale files organized by domain: `config/locales/en/<domain>.yml`, `config/locales/pt-BR/<domain>.yml`, etc.
- Every key in one locale must exist in **all** configured locales with matching interpolation variables.
- `*_html` suffix keys interpolate framework-marked-safe values only (typically `link_to` output). Never interpolate user data into an `_html` key.

## Multi-tenancy (only if project uses it)

If the project includes `acts_as_tenant` or a similar tenant-scoping library:

- **Classify every new model** as tenant-owned or shared in the PR description. Default is tenant-owned.
- **Tenant-owned models** declare `acts_as_tenant(:organization)` (or whatever the tenant association is named), have an `organization_id NOT NULL` column with FK, and include `organization_id` as the leading column of any composite index on frequently-queried fields.
- **Tenant resolution lives in `ApplicationController`** after authentication. Controllers never accept the tenant id from params.
- **Never `.unscoped` or `ActsAsTenant.without_tenant`** in domain code. Acceptable only in admin tooling and system-level maintenance tasks, both clearly namespaced (`Admin::`, `Maintenance::`).
- **Background jobs carry tenant context explicitly** — enqueue with the tenant id; re-establish `ActsAsTenant.current_tenant` at the start of `perform`. Never rely on a thread-local surviving the enqueue boundary.
- **Every tenant-owned model ships with a cross-tenant isolation spec** — a query under tenant B returns zero records created under tenant A.

## Quality gates

Default commands. Verify each binary exists before using it; don't hallucinate a tool the project hasn't installed:

- `bundle exec rspec` — full suite; fast enough to run before commit.
- `bundle exec rubocop` (or `bin/rubocop` if shipped). For autofix: `bin/rubocop -A` — re-run RSpec after autofixing in case style changes break a brittle assertion.
- `bin/brakeman --no-pager` — Brakeman SAST. The reviewer should diff Brakeman output against `main` to flag only **new** warnings.
- `bin/bundler-audit` — gem CVE check.

If the project doesn't ship `bin/brakeman` or `bin/bundler-audit`, gracefully skip them and note the gap in the PR's Test plan.

## Common Brakeman / XSS shapes to flag in reviews

- `<%= raw(user_input) %>`, `<%= some_var.html_safe %>`, `<%= sanitize(user_html) %>` — almost always wrong unless the source is framework-marked safe.
- `<%== some_var %>` — same as `raw`; flagged.
- `redirect_to params[...]` without an allow-list — open redirect.
- `Model.find_by_sql("... #{user_input} ...")` — SQLi.
- `params.permit!` or `params[:x].permit!` — mass-assignment.
- `update_attribute` skips validations — usually a smell.
- New routes that don't run through the project's `authenticate_user!` / authorization callbacks.

## PR body shape (Rails default)

```
## Summary
- <bullets — what shipped, why, link to `docs/features/<feature>.md` if one exists>

## Multi-tenancy classification
<"No new models." OR per-model classification per the project's tenancy ADR>

## Test plan
- [x] `bundle exec rspec` — N examples, 0 failures
- [x] `bundle exec rubocop` — clean
- [x] `bin/brakeman --no-pager` — clean
- [x] `bin/bundler-audit` — clean
- [ ] Manual smoke: <steps>

## Follow-ups (deliberately out of this PR)
- <items, with linked issue numbers if filed>

Closes #N
```

If the project doesn't use multi-tenancy, drop that section entirely.
