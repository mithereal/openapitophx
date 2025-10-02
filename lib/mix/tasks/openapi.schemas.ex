defmodule Mix.Tasks.Phx.Gen.Openapi.Schemas do
  use Mix.Task
  alias Openapitophx.OpenAPIGenerator

  @shortdoc "Generates schemas + LiveViews from OpenAPI YAML (supports --dry-run)"

  def run(args) do
    {opts, positional, _} = OptionParser.parse(args, switches: [dry_run: :boolean])

    yaml_path =
      List.first(positional) ||
        Mix.raise("Usage: mix openapi.schemas path/to/openapi.yaml [--dry-run]")

    dry_run? = Keyword.get(opts, :dry_run, false)

    Mix.Task.run("app.start")

    {:ok, spec} = OpenAPIGenerator.load_openapi(yaml_path)
    context = OpenAPIGenerator.detect_context(spec)

    IO.puts("Generating schemas + LiveViews for context: #{context} (dry run: #{dry_run?})")

    OpenAPIGenerator.get_schemas(spec)
    |> Enum.each(fn {name, schema} ->
      fields = OpenAPIGenerator.schema_to_fields(schema)
      OpenAPIGenerator.generate_resources(context, name, fields, !dry_run?)
    end)
  end
end
