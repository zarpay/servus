# frozen_string_literal: true

# =============================================================================
# Shared schema fragments
# =============================================================================
#
# These are the reusable pieces that services reference with `$ref`. They live
# in `config/` rather than `app/` or `lib/` on purpose:
#
#   - `app/` is autoloaded, and nothing ever references these constants by name
#     (refs are strings), so Zeitwerk would never load the file and the
#     fragments would never register.
#   - `lib/` is autoloaded too in this app (`config.autoload_lib` is on by
#     default in Rails 8), so it has the same problem.
#   - `config/` is not an autoload path, so an explicit `require` is correct.
#
# See config/initializers/servus.rb for where these get registered.
module WesterosSchemas
  # The `core` fragment holds primitives that several domains share. Keeping
  # them in one place means a change to how gold is represented happens once.
  CORE = {
    "$defs" => {
      # Gold is a non-negative integer count of dragons. Every service that
      # accepts or returns an amount refs this rather than restating it.
      "gold_dragons" => {
        "type" => "integer",
        "minimum" => 0,
        "description" => "A quantity of gold dragons",
        "example" => 50
      },
      # A database identifier. Used for house_id, vault_id, and friends.
      "record_id" => {
        "type" => "integer",
        "minimum" => 1,
        "description" => "A database identifier",
        "example" => 1
      },
      "timestamp" => {
        "type" => "string",
        "description" => "An ISO8601 timestamp",
        "example" => "2026-01-01T00:00:00Z"
      }
    }
  }.freeze

  # A second fragment, referenced BY the first-party fragment above, so the
  # demo exercises transitive `$ref` resolution (a ref whose target contains
  # another ref).
  HOUSES = {
    "$defs" => {
      "standing" => {
        "type" => "string",
        "enum" => %w[loyal neutral rebellious],
        "description" => "A house's standing with the crown",
        "example" => "loyal"
      },
      "summary" => {
        "type" => "object",
        "required" => %w[id name standing],
        "properties" => {
          "id" => { "$ref" => "#/core/$defs/record_id" },
          "name" => { "type" => "string", "example" => "Stark" },
          "standing" => { "$ref" => "#/houses/$defs/standing" }
        }
      }
    }
  }.freeze
end
