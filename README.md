# Phoenix OpenAPI Generator

Automatically generates **Phoenix Ecto schemas, migrations, and LiveViews** from OpenAPI 3.0.4 YAML files.

---

## Features

- Parses OpenAPI 3.0.4 YAML files (`.yaml` or `.yml`)
- Auto-detects context (`x-context`) or falls back to first schema
- Generates:
    - Ecto schemas with `belongs_to`, `has_many`, and `many_to_many` associations
    - Database migrations, including join tables
    - Phoenix LiveViews for CRUD operations
- Handles:
    - `$ref` references between schemas
    - Arrays and relationships
    - Many-to-many join schemas with additional fields

---

## Usage

Place your OpenAPI YAML in priv/openapi/:
priv/openapi/blog.yaml

Run the full generator:

```bash
mix phx.gen.openapi priv/openapi/blog.yaml
```

This generates:

* Ecto schemas
* Migrations (including join tables)
* Phoenix LiveViews for CRUD operations

## Partial generation:

```bash
mix phx.gen.openapi.schemas priv/openapi/blog.yaml    # Only schemas + LiveViews
mix phx.gen.openapi.migrations priv/openapi/blog.yaml # Only migrations
```

## Dry-run mode
Preview generator commands without creating files:

```bash
mix openapi.gen priv/openapi/blog.yaml --dry-run
```

## Notes

* Context detection uses x-context. If not present, the first schema name is used.
* Many-to-many relationships automatically generate join schemas and has_many :through associations.
* $ref references are used to generate belongs_to associations.
* LiveViews generated follow Phoenix naming conventions (New, Edit, Index, Show).
* Make sure to backup your project before running, as this will generate schemas, migrations, and LiveViews.
* You can still preview without running by passing false to the optional run? argument in generate_resources and create_join.
* Use --dry-run to preview commands before actual execution.

