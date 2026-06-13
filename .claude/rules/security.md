# Security baseline

Apply to **every** file. Non-negotiable for production code.

## Secrets

- Never commit secrets. Never paste them in code. Never log them.
- `.env*` files are read-only and reference-only — do not read them unless the user explicitly asks.
- Use the platform's secret store (AWS Secrets Manager, GCP Secret Manager, Vault, env via CI). Not config files.
- If you generate a secret (token, password, key) during a task, surface it once and tell the user to store it — never write it to disk.

## Input validation

- Validate at the boundary (HTTP layer, queue consumer, CLI parser). Once inside, trust the type.
- Use a schema validator (Zod, Pydantic, ajv, validator). Don't hand-roll.
- Reject unknown fields by default. `allowExtra: false`.
- Numeric: bounds-check. Strings: max length. Arrays: max items. UUIDs: format check.

## Auth & authz

- Authentication answers "who are you". Authorization answers "are you allowed to do this". They are different — do both.
- Authorize at the **closest layer to the resource**, not just at the route. A direct DB call must still check.
- Default deny. Whitelist allowed actions, not blacklist denied ones.
- Sessions: rotate on privilege change, expire on inactivity, invalidate server-side on logout.

## Injection

- Parameterized queries only. String-interpolated SQL is a bug.
- Escape on output, not on input — HTML, SQL, shell, log injection are all output-layer problems.
- Shell commands: pass args as arrays, never as a single string with user data.

## Crypto

- Don't roll your own. Use the platform's library (libsodium, WebCrypto, Python `cryptography`).
- Passwords: argon2id or bcrypt with cost ≥ 12. Never MD5/SHA1.
- Tokens: 32+ bytes from a CSPRNG.
- HTTPS everywhere. HSTS on. No mixed content.

## Logging

- Log enough to debug. Never log secrets, passwords, tokens, PII, PHI, payment data, or raw request bodies.
- Structured logs (JSON). Include `request_id`, `user_id` (not email), `action`, `result`.
- PII in logs is a breach. If you must include it, hash or redact.

## Dependencies

- Run `npm audit` / `pip-audit` / `cargo audit` in CI. Block merges on `high` and `critical`.
- Pin direct deps to exact versions. Use lockfiles. Update deliberately, not automatically.
- Review new deps before adding: maintainer count, last release, install size, transitive count.

## OWASP top 10 reminders

Always think about: broken access control, crypto failures, injection, insecure design, misconfig, vulnerable deps, auth failures, integrity failures (supply chain), logging failures, SSRF.
