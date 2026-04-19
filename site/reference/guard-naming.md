# Guard Naming Reference

Good guard names describe the condition being enforced rather than the action of checking it. That makes the generated service methods read naturally.

## Naming rule

| Prefer | Avoid |
| --- | --- |
| `OpenAccountGuard` | `CheckOpenAccountGuard` |
| `SufficientBalanceGuard` | `ValidateSufficientBalanceGuard` |
| `EligibleCourierGuard` | `RequireEligibleCourierGuard` |

## Why this rule helps

A well-named guard produces method names that read like domain language, such as `enforce_sufficient_balance!` or `check_open_account?`. The service body becomes clearer when the guard name describes the condition rather than duplicating the verb of enforcement.
