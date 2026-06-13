# PHP / Laravel

Extends `@.claude/rules/code-style.md`. Applies when editing `*.php`.

## PHP

- PHP 8.2+. **PSR-12** formatting (Laravel Pint). `declare(strict_types=1);` at the top of
  every file.
- Type everything: parameter types, return types, typed properties. Use enums, readonly
  properties, constructor property promotion, and `match` over long `switch`.
- Composer with a committed lockfile. PHPStan/Larastan at a high level (≥ 6) in CI.

## Laravel

- **Eloquent, but thin models.** Business logic lives in Action/Service classes, not in
  controllers or fat models. Controllers orchestrate; they don't compute.
- **Validation at the edge** via Form Requests (or `$request->validate()`), always. Never
  trust `$request->all()` into `create()` — guard mass assignment with `$fillable`.
- **Authorization** via Policies / Gates, checked close to the resource — not just route
  middleware. Default deny.
- **Queries:** Eloquent or the query builder — parameter-bound by default; never interpolate
  user input into `DB::raw`. Eager-load to kill N+1 (`with()`); add DB indexes for hot
  lookups. Wrap multi-step writes in `DB::transaction`.
- **Migrations** are forward-only in shared environments: reversible where possible, never
  edit a shipped migration — add a new one. Foreign keys + `NOT NULL` + constraints in the
  schema.
- Jobs/queues for slow work; make handlers idempotent (`ShouldBeUnique` / dedup keys).
  Config and secrets via `config()` + env, never `env()` outside config files.
- Resources/API: Eloquent API Resources for output shaping; don't leak model internals.

## Tests

- **Pest** (or PHPUnit) with model factories — never hand-built arrays. `RefreshDatabase`
  against a real MySQL/Postgres, not SQLite, so migrations and DB behavior are exercised.
- Feature tests for HTTP endpoints (auth, validation, authorization paths); unit tests for
  Actions/Services. Freeze time with `travelTo`, fake queues/mail/events at the boundary.
