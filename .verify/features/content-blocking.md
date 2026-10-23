# Content blocking

Harbor blocks known advertising and tracking requests inside the WebKit engine by default. A site can be exempted, which keeps blocking on for every other site.

## Sub-features

- `default-on-blocking`: Blocks tracker requests for every page unless the policy is turned off.
  - Intent: a new browser window protects the user without setup.
  - Behaviour: the engine compiles one WebKit content rule list with a block rule per tracker domain, and installs it before the first navigation.
  - Outcome: `WebKitEngine(isBackground:contentBlocking:)` reports `isContentBlocking == true` with the standard policy.
- `site-exception`: Exempts one host from every tracker rule.
  - Intent: a user can allow a site that breaks when its trackers are blocked.
  - Behaviour: `ContentBlockingPolicy.exempting(host)` returns a new policy whose rules carry `unless-domain` for `*host`, so the host and its subdomains are not blocked.
  - Outcome: the policy is still on, and the exception appears in every rule.
- `disabled-policy`: Turns blocking off completely.
  - Intent: a user or a test can load pages with no content rules.
  - Behaviour: a policy with `isEnabled == false` produces no rule list, and the engine installs nothing.
  - Outcome: `isContentBlocking == false`.
- `webkit-accepted-rules`: The generated rule list compiles in WebKit.
  - Intent: a malformed rule never reaches a browsing session silently.
  - Behaviour: the rule list is valid JSON that `WKContentRuleListStore` accepts.
  - Outcome: compilation returns a rule list, not an error.

## How to get to it (user POV)

- Blocking is on for every new window. There is no toggle in the interface yet.
- The policy is chosen when an engine is created. `WebKitEngine(isBackground:contentBlocking:)` takes a `ContentBlockingPolicy`, and the default is `.standard`.
- A site exception is set with `ContentBlockingPolicy.standard.exempting("example.com")` and applies to the engine created with that policy.

## Verification Suites (Targeted Test Commands)

- **Unit Tests:** `swift test --filter ContentBlockingTests` (covers the policy values, the exception, the disabled state, and the generated rule list, including WebKit compilation).
- **Integration Tests:** `swift test --filter ContentBlockingEngineIntegrationTests` (covers that the engine installs the rules, skips them when disabled, and keeps them on with an exception).
- **Allowlisted Verification:** `sh .verify/run.sh unit` and `sh .verify/run.sh integration` (entries `unit` and `integration` in `.verify/verify.toml`).
- **Preconditions:** macOS with WebKit. No network access is needed.

## Gotchas

- The tracker list is a starter list of six domains (`ContentBlockingPolicy.trackerDomains`), not a full filter list. Expanding it is a data change that needs its own review.
- Blocking is verified by the rule list and by the engine applying it. No test loads a real tracker request, because the testing rules forbid live external dependencies.
- The exception is fixed for the life of an engine. Changing it means creating a new engine. A per-site control and its persistence are not built yet.
- The engine compiles rules under the identifier `harbor-content-blocking`. Two engines with different policies overwrite each other's compiled list in the shared store.
- `load` and `loadHTML` wait for the rules before navigating, so the first page is never loaded without them when blocking is on.
