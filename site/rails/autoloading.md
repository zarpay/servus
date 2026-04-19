# Rails Autoloading

Servus fits naturally into Rails autoloading when services follow predictable namespaces and file locations. That alignment is part of what makes the framework pleasant in Rails applications.

## Example

```text
app/services/users/create/service.rb
```

Rails will autoload that file as:

```ruby
Users::Create::Service
```

## Why this matters

Consistent autoloading keeps services easy to discover. Teams can search by domain action and trust the namespace to match the file layout.
