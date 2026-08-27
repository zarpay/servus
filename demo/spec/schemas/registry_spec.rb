# frozen_string_literal: true

require "rails_helper"

# =============================================================================
# The schema registry
# =============================================================================
#
# Features exercised:
#   - Servus::Schema.register / fetch / resolve / ref / keys / compile_all
#   - $ref resolution, including transitive refs
#   - Sibling-merge override semantics
#   - generation, snapshot / restore
#   - Every error class the registry can raise
#
# ---------------------------------------------------------------------------
# What problem the registry solves
# ---------------------------------------------------------------------------
#
# Servus 1.0 removed constant- and file-based schemas: a contract is declared
# inline, in the service that implements it. That is good for reading one
# service and bad for a codebase with two hundred of them, because "a gold
# amount is a non-negative integer" would be restated two hundred times.
#
# The registry is the answer. A fragment is registered once and referenced with
# a standard JSON Schema `$ref`. The service still declares its contract
# explicitly — it just names a shared type instead of restating it.
#
# The fragments this app registers live in config/schemas/westeros.rb and are
# registered by config/initializers/servus.rb.
RSpec.describe Servus::Schema do
  describe "reading registered fragments" do
    it "lists what the initializer registered" do
      expect(described_class.keys).to include("core", "houses")
    end

    it "fetches a whole fragment" do
      expect(described_class.fetch("core")).to have_key("$defs")
    end

    it "fetches a definition by path" do
      gold = described_class.fetch("core", "$defs", "gold_dragons")

      expect(gold["type"]).to eq("integer")
      expect(gold["minimum"]).to eq(0)
    end

    # `fetch` returns what was authored; `resolve` returns it compiled. For a
    # fragment with no refs of its own the two agree, which is why the contrast
    # only shows up on `houses` below.
    it "returns fragments as authored, refs intact" do
      summary = described_class.fetch("houses", "$defs", "summary")

      expect(summary.dig("properties", "id")).to eq({ "$ref" => "#/core/$defs/record_id" })
    end

    it "resolves refs when asked to" do
      summary = described_class.resolve("houses", "$defs", "summary")

      expect(summary.dig("properties", "id", "type")).to eq("integer")
    end

    # Transitive: houses/summary refs houses/standing, which is in a different
    # part of the same fragment, and core/record_id, which is in another one.
    it "follows refs across fragments and within them" do
      summary = described_class.resolve("houses", "$defs", "summary")

      expect(summary.dig("properties", "standing", "enum"))
        .to eq(%w[loyal neutral rebellious])
    end
  end

  describe "building refs" do
    # Prefer this to hand-writing the string — it is typo-proof in the prefix
    # and the separator, which are the parts people get wrong.
    it "builds a ref hash from a key and path" do
      expect(described_class.ref("core", "$defs", "gold_dragons"))
        .to eq({ "$ref" => "#/core/$defs/gold_dragons" })
    end
  end

  describe "compiling everything at once" do
    # Useful for emitting one JSON asset for an API description or client
    # codegen, and as a CI check: it fails if ANY registered fragment contains
    # a ref that cannot be resolved.
    it "returns every fragment with refs resolved" do
      compiled = described_class.compile_all

      expect(compiled.keys).to include("core", "houses")
      expect(compiled.to_s).not_to include("$ref")
    end

    it "serializes to JSON" do
      expect { JSON.generate(described_class.compile_all) }.not_to raise_error
    end
  end

  # Everything below mutates the registry, so it runs inside the snapshot /
  # restore context from spec/support/schema_registry.rb.
  describe "registering fragments", :schema_registry do
    it "accepts a fragment and makes it referenceable" do
      described_class.register("scratch", { "$defs" => { "n" => { "type" => "integer" } } })

      expect(described_class.resolve("scratch", "$defs", "n")).to eq({ "type" => "integer" })
    end

    it "deep-freezes what it stores, so a reader cannot corrupt it" do
      described_class.register("scratch", { "$defs" => { "n" => { "type" => "integer" } } })

      expect { described_class.fetch("scratch")["$defs"] = {} }.to raise_error(FrozenError)
    end

    it "copies the input, so mutating the source afterwards changes nothing" do
      source = { "$defs" => { "n" => { "type" => "integer" } } }
      described_class.register("scratch", source)

      source["$defs"]["n"]["type"] = "string"

      expect(described_class.fetch("scratch", "$defs", "n", "type")).to eq("integer")
    end

    # Re-registering an identical value is a no-op, which is what makes it safe
    # to run registration from a `to_prepare` block on every reload.
    it "treats an identical re-registration as a no-op" do
      fragment = { "$defs" => { "n" => { "type" => "integer" } } }
      described_class.register("scratch", fragment)

      expect { described_class.register("scratch", fragment.dup) }
        .not_to change(described_class, :generation)
    end

    it "replaces and invalidates when the value differs" do
      described_class.register("scratch", { "$defs" => { "n" => { "type" => "integer" } } })

      expect { described_class.register("scratch", { "$defs" => {} }) }
        .to change(described_class, :generation)
    end

    it "rejects a key containing the ref path separator" do
      expect { described_class.register("a/b", { "$defs" => {} }) }
        .to raise_error(Servus::Schema::InvalidKeyError, %r{'/'})
    end

    it "rejects a fragment that is not a Hash" do
      expect { described_class.register("scratch", "nope") }
        .to raise_error(ArgumentError, /Hash/)
    end
  end

  describe "when a lookup fails" do
    # The registry never returns nil. A nil would let a service that appears to
    # declare a contract run with no validation at all — the exact failure the
    # 1.0 schema work set out to eliminate.
    it "raises for an unregistered key and suggests the nearest one" do
      expect { described_class.fetch("cor") }
        .to raise_error(Servus::Schema::UnknownKeyError, /Did you mean.*"core"/)
    end

    it "raises for a path that is not there, listing what is" do
      expect { described_class.fetch("core", "$defs", "gold_dragon") }
        .to raise_error(Servus::Schema::RefNotFoundError, /Available keys:.*gold_dragons/)
    end
  end

  describe "compiling an ad-hoc schema" do
    it "resolves refs in a schema that is not attached to any class" do
      compiled = described_class.compile(
        { "type" => "object", "properties" => { "fee" => described_class.ref("core", "$defs", "gold_dragons") } }
      )

      expect(compiled.dig("properties", "fee", "type")).to eq("integer")
    end

    # Keys written alongside a $ref override the fragment they resolve to.
    # This is what makes a shared fragment usable at a specific call site —
    # take the shape, then re-describe it for this use.
    #
    # Note it differs from JSON Schema 2019-09+, where siblings are an
    # intersection rather than an override.
    it "lets sibling keys override the fragment" do
      compiled = described_class.compile(
        { "$ref" => "#/core/$defs/gold_dragons", "description" => "The fee charged", "maximum" => 10 }
      )

      expect(compiled["description"]).to eq("The fee charged")
      expect(compiled["maximum"]).to eq(10)
      expect(compiled["type"]).to eq("integer")
      expect(compiled["minimum"]).to eq(0)
    end

    it "rejects a local ref by name rather than failing as a missing fragment" do
      expect { described_class.compile({ "$ref" => "#/$defs/thing" }) }
        .to raise_error(Servus::Schema::InvalidRefError, /local ref/)
    end

    it "rejects a remote ref" do
      expect { described_class.compile({ "$ref" => "https://example.com/s.json" }) }
        .to raise_error(Servus::Schema::InvalidRefError, /Remote and file refs/)
    end

    it "detects a cycle and names every hop", :schema_registry do
      described_class.register("a", { "node" => { "$ref" => "#/b/node" } })
      described_class.register("b", { "node" => { "$ref" => "#/a/node" } })

      expect { described_class.compile({ "$ref" => "#/a/node" }) }
        .to raise_error(Servus::Schema::CircularReferenceError, %r{#/a/node -> #/b/node -> #/a/node})
    end
  end
end
