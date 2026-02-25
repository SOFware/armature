# Armature

Declarative trees of related records using factory_bot.

Armature composes factory_bot factories into **blueprints** that know how to create, find, and relate records. You register blueprints with a **base** class, then build entire object graphs with a nested DSL:

```ruby
TestArmature.new do
  team "Engineering" do
    user "Alice"
    admin "Bob"

    project "API" do
      task "Auth", priority: "high"
      task "Caching"
    end
  end
end
```

Each method call creates a record (or finds an existing one), and nesting establishes parent-child context automatically. No manual foreign key wiring.

## Installation

```ruby
gem "armature"
```

## Usage

### Blueprints

A blueprint wraps a single factory_bot factory and declares how it participates in the tree:

```ruby
class TeamBlueprint < Armature::Blueprint
  handles :team
  factory :team
  collection :teams
  parent :none
  permitted_attrs %i[name]

  def team(name, attrs = {}, &block)
    @attrs = attrs.merge(name: name)
    object = find(name) || create_object
    update_state_for_block(object, &block) if block
    object
  ensure
    reset_attrs
  end

  private

  def create_object
    create(:team, attrs).tap { |record| collection << record }
  end

  def attrs
    permitted_attrs @attrs
  end
end
```

#### Blueprint DSL

| Method | Purpose |
|--------|---------|
| `handles :method_name` | Methods this blueprint exposes on the armature |
| `factory :name` | Which factory_bot factory to use (inferred from class name if omitted) |
| `collection :name` | Collection name for tracking created records |
| `parent :name` | How to find the parent record (`:none`, `:self`, or a method on `current`) |
| `parent_key :foreign_key` | Foreign key column linking to the parent |
| `permitted_attrs %i[...]` | Attributes allowed through to factory_bot |
| `nested_attrs key => [...]` | For `accepts_nested_attributes_for` |

#### Finding records

Blueprints automatically prevent duplicates. `find(name)` checks the in-memory collection first, then falls back to the database. `find_by(criteria)` works with arbitrary attributes.

#### Parent context

When a block is passed to a blueprint method, `update_state_for_block` saves the current context, sets the new record as `current.resource`, executes the block, then restores the previous context. Child blueprints read their parent from `current`:

```ruby
class UserBlueprint < Armature::Blueprint
  handles :user
  parent :team         # reads current.team
  parent_key :team_id  # sets team_id on created records
  # ...
end
```

### Base (the armature)

Register blueprints and optional extra collections:

```ruby
class TestArmature < Armature::Base
  blueprint TeamBlueprint
  blueprint UserBlueprint
  blueprint ProjectBlueprint
  blueprint TaskBlueprint

  collection :tags  # extra collection not from a blueprint
end
```

The base class:

- Instantiates each blueprint and delegates its `handles` methods
- Initializes a `Set` for each collection (e.g. `teams_collection`)
- Tracks `current` state so nested blocks know their parent context
- Deduplicates records via each blueprint's `find` logic

### Presets

Presets are named class methods that build a preconfigured armature:

```ruby
class TestArmature < Armature::Base
  # ...

  preset :dev_team do
    team "Engineering" do
      user "Alice"
      project "Main" do
        task "Setup"
      end
    end
  end
end

# In a test:
let(:foundry) { TestArmature.dev_team }
```

### Reopening

Add more records to an existing armature:

```ruby
foundry = TestArmature.dev_team
foundry.reopen do
  team "Design" do
    user "Carol"
  end
end
```

### Building from existing objects

Start from records already in the database:

```ruby
foundry = TestArmature.new
foundry.from(existing_team) do
  user "New hire"
end
```

### Lifecycle hooks

Override `setup` and `teardown` in your base subclass for pre/post processing:

```ruby
class TestArmature < Armature::Base
  private

  def setup
    @pending_rules = []
  end

  def teardown
    process_pending_rules
  end
end
```

## Snapshot Caching

When using ActiveRecord, Armature can snapshot preset data to disk and restore it instead of re-running factories. This is useful for speeding up test suites where the same preset is called many times.

Enable with an environment variable:

```
ARMATURE_CACHE=1 bundle exec rspec
```

Or configure directly:

```ruby
Armature::Snapshot.enabled = true
Armature::Snapshot.storage_path = "tmp/armature"  # default
Armature::Snapshot.source_paths = [
  "lib/blueprints/**/*.rb",
  "lib/test_armature.rb"
]
```

Snapshots are invalidated automatically when the schema version changes or when source files listed in `source_paths` are modified. Data is captured using database-native copy operations (PostgreSQL `COPY`, SQLite `INSERT`) and restored with referential integrity checks temporarily disabled.

## Similarity Detection

Armature can detect when presets have overlapping structure, highlighting consolidation opportunities. When enabled, it records the normalized blueprint call tree of each preset and compares against previously seen presets.

Enable with an environment variable:

```
ARMATURE_SIMILARITY=1 bundle exec rspec
```

Or configure directly:

```ruby
Armature::Similarity.enabled = true
```

When two presets share identical structure or one is structurally contained within another, a warning is printed to stderr:

```
[Armature] Preset :basic and :extended have identical structure (team > [project > [task], user])
[Armature] Preset :simple is structurally contained within :complex
```

Each unique pair is warned once per process. The detection normalizes trees by deduplicating sibling nodes (keeping the richest subtree), collapsing pass-through chains, and sorting alphabetically. This means presets that build the same *shape* of data are detected regardless of the specific names or attribute values used.

## Requirements

- Ruby >= 3.2
- factory_bot >= 6.0
- ActiveRecord (optional, for snapshot caching)

## License

MIT
