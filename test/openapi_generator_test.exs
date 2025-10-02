defmodule Openapitophx.OpenAPIGeneratorTest do
  use ExUnit.Case, async: true
  alias Openapitophx.OpenAPIGenerator

  @sample_yaml_path Path.join([__DIR__, "../../priv/openapi/blog.yaml"])

  describe "load_openapi/1" do
    test "loads a valid OpenAPI YAML file" do
      {:ok, spec} = OpenAPIGenerator.load_openapi(@sample_yaml_path)
      assert is_map(spec)
      assert Map.has_key?(spec, "components")
      assert Map.has_key?(spec["components"], "schemas")
    end

    test "returns error for non-existent file" do
      assert {:error, _} = OpenAPIGenerator.load_openapi("invalid_path.yaml")
    end
  end

  describe "detect_context/1" do
    test "detects x-context if present" do
      {:ok, spec} = OpenAPIGenerator.load_openapi(@sample_yaml_path)
      context = OpenAPIGenerator.detect_context(spec)
      assert context == "Blog"
    end

    test "falls back to first schema name if x-context missing" do
      spec = %{
        "components" => %{
          "schemas" => %{
            "User" => %{"type" => "object"},
            "Post" => %{"type" => "object"}
          }
        }
      }

      context = OpenAPIGenerator.detect_context(spec)
      assert context == "Post"
    end
  end

  describe "get_schemas/1" do
    test "returns all schemas as list of tuples" do
      {:ok, spec} = OpenAPIGenerator.load_openapi(@sample_yaml_path)
      schemas = OpenAPIGenerator.get_schemas_map(spec)
      assert is_list(schemas)
      assert Enum.any?(schemas, fn {name, _schema} -> name == "User" end)
    end
  end

  describe "schema_to_fields/1" do
    test "converts schema properties into fields" do
      schema = %{
        "properties" => %{
          "name" => %{"type" => "string"},
          "email" => %{"type" => "string"},
          "posts" => %{"type" => "array", "items" => %{"$ref" => "#/components/schemas/Post"}}
        }
      }

      fields = OpenAPIGenerator.schema_to_fields(schema)
      assert Enum.any?(fields, fn f -> f.name == "name" end)
      assert Enum.any?(fields, fn f -> f.name == "posts" and f.type == "array" end)
    end
  end

  describe "run/2" do
    test "runs the generator without errors" do
      {:ok, spec} = OpenAPIGenerator.load_openapi(@sample_yaml_path)
      context = OpenAPIGenerator.detect_context(spec)

      # Since generate_resources just logs, no side effects expected
      assert [
               %{
                 schema:
                   "mix phx.gen.context blog Post blog/Post content:string tags:references title:string user:string",
                 liveview:
                   "mix phx.gen.live blog Post blog/Post content:string tags:references title:string user:string",
                 joins: [
                   "mix phx.gen.schema PostsTag post_tags post:references:post tags:references:tags extra_note:string"
                 ]
               },
               %{
                 schema: "mix phx.gen.context blog Tag blog/Tag name:string",
                 liveview: "mix phx.gen.live blog Tag blog/Tag name:string",
                 joins: []
               },
               %{
                 schema:
                   "mix phx.gen.context blog User blog/User email:string name:string posts:references",
                 liveview:
                   "mix phx.gen.live blog User blog/User email:string name:string posts:references",
                 joins: []
               }
             ] ==
               OpenAPIGenerator.run(@sample_yaml_path, context)
    end
  end
end
