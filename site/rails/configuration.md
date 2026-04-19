# Rails Configuration

Servus can be configured to fit how a Rails application organizes schemas, logging, guards, events, and background execution. The goal of configuration is not to change the mental model of the framework. The goal is to connect that model to application infrastructure.

## Main areas of configuration

| Area | What it controls |
| --- | --- |
| Schema root | Where file-based schemas are resolved |
| Schema cache | Whether loaded schemas are reused |
| Logging level | How service activity appears in application logs |
| ActiveJob integration | How async execution is wired |
| Guard and event loading | How reusable framework extensions are discovered |

## Practical guidance

A small application can begin with very little configuration. As the service layer grows, explicit configuration becomes more useful because it makes schemas, logging, and event handling easier to reason about across the project.
