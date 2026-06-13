# Testing

## Pyramid

- **Lots of unit tests** — fast, deterministic, no I/O. Run on every save.
- **Some integration tests** — real DB, real HTTP, real queue. Run on every PR.
- **Few E2E tests** — golden paths only. Run on merge to main.

If the pyramid is inverted (lots of E2E, few unit), the test suite is slow, flaky, and expensive. Rebalance.

## What to test

- Public behavior, not private implementation. Refactoring should not break tests.
- One assertion per test, conceptually. Multiple `expect`s are fine if they're checking one outcome.
- Test edge cases: empty, one, many, max, off-by-one, negative, zero, null, unicode, very long, concurrent.
- Test the **error paths**. Most bugs hide there.

## What NOT to test

- Framework code (Express routing, React rendering primitives) — already tested upstream.
- Third-party libraries — already tested by their authors.
- Trivial getters/setters / pure data shaping.
- "100% coverage" as a goal. 70–85% on meaningful code is healthier than 100% with garbage assertions.

## Naming

- `describe("UserService")` → `it("rejects emails over 254 chars")`. Read like sentences.
- Test names state the **expected behavior**, not the input: `"returns 404 when user does not exist"`, not `"test getUser missing"`.

## Determinism

- No flaky tests. A flaky test is a bug — either in the test or in the system. Fix or delete.
- No `sleep` / `setTimeout` to wait for async. Use proper polling helpers or test doubles.
- Freeze time (`vi.useFakeTimers`, `freezegun`, `time.Now`-stubbing in Go).
- Seed all randomness.

## Fixtures & doubles

- Build via factories, not literal JSON blobs. Factories survive schema changes.
- Mock at the **boundary** (HTTP, DB), not at internal interfaces. Mocking your own functions tests the mock, not the code.
- Real DB in integration tests > mocked DB. Real DB tests catch migration breaks.

## CI

- All tests run on every PR. No `--skip` in main.
- Test suite < 5 min for unit, < 15 min for integration. If slower, parallelize or split.
- Coverage as a signal, not a gate. Drops > 2% on a PR warrant a comment.
