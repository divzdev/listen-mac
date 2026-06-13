# Python

Extends `@.claude/rules/code-style.md`. Applies when editing `*.py`.

## Tooling

- **uv** for envs/deps (or poetry if the repo uses it). Pin exact versions in app code.
- **ruff** for lint + format (replaces black/isort/flake8). **mypy** in strict mode for types.
- **pytest** for tests. Target Python 3.12+ unless the repo says otherwise.

## Style

- PEP 8 via ruff. snake_case for functions/vars, PascalCase for classes, SCREAMING_SNAKE for
  constants. Module names short and lowercase.
- **Type-hint everything** public. No bare `Any` at boundaries. Prefer `X | None` over
  `Optional[X]`. Use `from __future__ import annotations` where it helps.
- Dataclasses / Pydantic models over loose dicts. Make illegal states unrepresentable.
- f-strings only. No `%` or `.format()`. No mutable default arguments.
- Pathlib over `os.path`. Context managers for anything with a resource.

## Validation & errors

- **Pydantic v2** at every boundary (HTTP body, queue message, config). `model_config` with
  `extra="forbid"` — reject unknown fields.
- Raise specific exceptions with the offending value in the message. Never bare `except:`;
  never `except Exception: pass`.

## Async & data

- Don't mix sync and async DB drivers. If the framework is async (FastAPI), the data layer is
  async end to end.
- SQLAlchemy 2.0 style or the repo's ORM — parameterized queries only, never f-string SQL.

## Tests

- pytest with fixtures/factories (factory_boy or plain functions), not literal blobs.
- `freezegun` for time, seed all randomness, `pytest.mark.parametrize` for edge cases.
- Real DB in integration tests (testcontainers / a disposable Postgres), mock only true
  external HTTP.
