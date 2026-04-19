# Testing Guards and Events

Guards and event handlers deserve direct tests because they capture reusable policy and reusable orchestration.

## Guard testing

A guard spec should prove both the validation decision and the resulting error metadata. That keeps reusable policy stable even as the services that depend on it evolve.

## Event testing

Event tests can prove two different things. One test can prove that a service emits the expected event. Another can prove that a handler invokes the expected downstream service when the event fires.

| Test type | What it protects |
| --- | --- |
| Guard test | Shared domain validation |
| Service event test | Emission from the business action |
| Handler test | Reaction logic and argument mapping |

## Why separate tests help

When event emission and handler behavior are tested separately, teams can refactor the service and the handler with clearer feedback about what changed.
