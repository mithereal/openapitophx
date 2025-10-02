defmodule Mix.Tasks.Phx.Gen.Openapi do
  use Mix.Task
  alias Openapitophx.OpenAPIGenerator
  alias Phoenix.Naming

  @shortdoc "Generates schemas, join tables, and LiveViews from OpenAPI YAML (supports --dry-run)"

  def run(args) do
    {opts, positional, _} = OptionParser.parse(args, switches: [dry_run: :boolean])

    yaml_path =
      List.first(positional) ||
        Mix.raise("Usage: mix openapi.gen path/to/openapi.yaml [--dry-run]")

    dry_run? = Keyword.get(opts, :dry_run, false)

    Mix.Task.run("app.start")

    {:ok, spec} = OpenAPIGenerator.load_openapi(yaml_path)
    context = OpenAPIGenerator.detect_context(spec)

    IO.puts("Generating for context: #{context} (dry run: #{dry_run?})")

    OpenAPIGenerator.get_schemas(spec)
    |> Enum.each(fn {name, schema} ->
      fields = OpenAPIGenerator.schema_to_fields(schema)

      # Generate schema + LiveView
      OpenAPIGenerator.generate_resources(context, name, fields, !dry_run?)

      # Generate join tables
      Enum.each(fields, fn f ->
        if f.type == "array" and Map.has_key?(f.props, "x-relation") do
          join_opts = %{
            join_schema: f.props["x-join-schema"],
            join_fields: f.props["x-join-fields"] || %{}
          }

          OpenAPIGenerator.create_join(
            context,
            name,
            Naming.camelize(f.name),
            join_opts,
            !dry_run?
          )
        end
      end)
    end)
  end
end
