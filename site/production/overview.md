# Production Overview

Servus was developed to support ZAR and is used extensively in ZAR production systems. That makes ZAR Core an important real-world consumer of the framework. It does **not** mean that every production convention in ZAR Core should be treated as part of the framework itself.

## How to read this section

This section documents the conventions that ZAR layers on top of Servus after the framework boundary is already understood. The purpose is to help readers learn from production experience without confusing downstream house style with the native API surface.

## The framing in one table

| Statement | How to read it |
| --- | --- |
| Servus is used heavily in ZAR production systems | Evidence that the framework has a serious real-world consumer |
| ZAR uses Dry Initializer `option` declarations | A production convention, not the opening definition of Servus |
| ZAR uses `schema_key` naming patterns | A production convention layered on top of Servus schema support |
| ZAR has testing and usage conventions for services | Useful best practices, but still downstream guidance |
