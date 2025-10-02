defmodule Openapitophx.OpenAPIGenerator do
  require Logger
  alias Phoenix.Naming

  # -------------------------------
  # Public API
  # -------------------------------

  def load_openapi(path) when is_binary(path) do
    case YamlElixir.read_from_file(path) do
      {:ok, yaml_map} -> {:ok, yaml_map}
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, e}
  end

  def get_schemas(%{"components" => %{"schemas" => schemas}}), do: schemas
  def get_schemas(_), do: %{}

  @doc """
  Returns a list of {name, schema} tuples from OpenAPI YAML.
  """
  def get_schemas_map(%{"components" => %{"schemas" => schemas}}) when is_map(schemas) do
    Enum.map(schemas, fn {name, schema} -> {name, schema} end)
  end

  def get_schemas_map(_), do: []

  def detect_context(%{"x-context" => context}), do: context

  def detect_context(%{"components" => %{"schemas" => schemas}}) when map_size(schemas) > 0 do
    schemas |> Map.keys() |> List.first()
  end

  def detect_context(_), do: "Default"

  def schema_to_fields(%{"properties" => props}) do
    Enum.map(props, fn {name, info} ->
      %{
        name: name,
        type: Map.get(info, "type", "string"),
        props: Map.drop(info, ["type"])
      }
    end)
  end

  def schema_to_fields(_), do: []

  @doc """
  Run the generator on a YAML path. Returns a map of commands.
  """
  def run(yaml_path, opts \\ []) do
    opts =
      cond do
        # if string, wrap in list
        is_binary(opts) -> [opts]
        # already a list, fine
        is_list(opts) -> opts
        # fallback to empty list
        true -> []
      end

    # default dry_run true for test safety
    dry_run? = Keyword.get(opts, :dry_run, true)

    with {:ok, spec} <- load_openapi(yaml_path) do
      context = detect_context(spec)

      results =
        get_schemas(spec)
        |> Enum.map(fn {name, schema} ->
          fields = schema_to_fields(schema)

          {schema_cmd, liveview_cmd} = generate_resources(context, name, fields, !dry_run?)

          join_cmds =
            Enum.filter_map(
              fields,
              fn f -> f.type == "array" and Map.has_key?(f.props, "x-relation") end,
              fn f ->
                join_opts = %{
                  join_schema: f.props["x-join-schema"],
                  join_fields: f.props["x-join-fields"] || %{}
                }

                create_join(context, name, Naming.camelize(f.name), join_opts, !dry_run?)
              end
            )

          %{
            schema: schema_cmd,
            liveview: liveview_cmd,
            joins: join_cmds
          }
        end)

      results
    else
      {:error, reason} ->
        Logger.error("Failed to load YAML: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # -------------------------------
  # Generator Helpers
  # -------------------------------

  def generate_resources(context, name, fields, run? \\ false) do
    schema_name = Naming.camelize(name)
    context_name = Naming.underscore(context)

    field_args =
      fields
      |> Enum.map(fn f -> "#{f.name}:#{map_type(f.type)}" end)
      |> Enum.join(" ")

    schema_cmd =
      "mix phx.gen.context #{context_name} #{schema_name} #{context_name}/#{schema_name} #{field_args}"

    liveview_cmd =
      "mix phx.gen.live #{context_name} #{schema_name} #{context_name}/#{schema_name} #{field_args}"

    if run? do
      run_command(schema_cmd)
      run_command(liveview_cmd)
    end

    {schema_cmd, liveview_cmd}
  end

  def create_join(context, left, right, opts \\ %{}, run? \\ false) do
    left_table = Naming.underscore(left)
    right_table = Naming.underscore(right)
    join_schema = Map.get(opts, :join_schema, "#{left}#{right}")
    join_table = "#{left_table}_#{right_table}"

    extra_fields =
      Map.get(opts, :join_fields, %{})
      |> Enum.map(fn {name, type_map} ->
        type = Map.get(type_map, :type, "string")
        "#{name}:#{type}"
      end)
      |> Enum.join(" ")

    join_cmd =
      "mix phx.gen.schema #{join_schema} #{join_table} " <>
        "#{left_table}:references:#{left_table} #{right_table}:references:#{right_table} #{extra_fields}"

    if run?, do: run_command(join_cmd)
    join_cmd
  end

  # -------------------------------
  # Internal
  # -------------------------------

  defp run_command(cmd) do
    IO.puts("Executing: #{cmd}")
    {_, exit_code} = System.cmd("sh", ["-c", cmd], into: IO.stream(:stdio, :line))
    if exit_code != 0, do: IO.puts("Command failed: #{cmd}")
  end

  defp map_type("string"), do: "string"
  defp map_type("integer"), do: "integer"
  defp map_type("boolean"), do: "boolean"
  defp map_type("number"), do: "float"
  defp map_type("array"), do: "references"
  defp map_type(_), do: "string"
end
