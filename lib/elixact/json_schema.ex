defmodule Elixact.JsonSchema do
  @moduledoc """
  A module for converting Elixact schema definitions into JSON Schema format.
  Handles field types, metadata, references, and definitions generation.
  """
  alias Elixact.JsonSchema.{ReferenceStore, TypeMapper}

  def from_schema(schema) when is_atom(schema) do
    {:ok, store} = ReferenceStore.start_link()

    try do
      # First, generate the main schema
      result = generate_schema(schema, store)

      # Process any referenced schemas
      process_referenced_schemas(store)

      # Add definitions to the result
      definitions = ReferenceStore.get_definitions(store)

      if map_size(definitions) > 0 do
        Map.put(result, "definitions", definitions)
      else
        result
      end
    after
      ReferenceStore.stop(store)
    end
  end

  defp process_referenced_schemas(store) do
    # Get all references that need to be processed
    references = ReferenceStore.get_references(store)

    # Generate schemas for each reference
    Enum.each(references, fn module ->
      if not ReferenceStore.has_definition?(store, module) do
        generate_schema(module, store)
      end
    end)
  end

  defp generate_schema(schema, store) do
    # Get schema config
    config = schema.__schema__(:config) || %{}

    # Build base schema with config
    base_schema =
      %{
        "type" => "object",
        "title" => config[:title],
        "description" => config[:description] || schema.__schema__(:description),
        "properties" => %{},
        "required" => []
      }
      |> maybe_add_additional_properties(config[:strict])
      |> Map.reject(fn {_, v} -> is_nil(v) end)

    fields = schema.__schema__(:fields)

    # Process fields first
    schema_with_fields =
      Enum.reduce(fields, base_schema, fn {name, field_meta}, schema_acc ->
        # Add to properties
        properties = Map.get(schema_acc, "properties", %{})

        # Convert type and merge with field metadata
        field_schema =
          TypeMapper.to_json_schema(field_meta.type, store)
          |> Map.merge(convert_field_metadata(field_meta))
          |> Map.reject(fn {_, v} -> is_nil(v) end)

        updated_properties = Map.put(properties, Atom.to_string(name), field_schema)
        schema_acc = Map.put(schema_acc, "properties", updated_properties)

        # Add to required if needed
        if field_meta.required do
          required = Map.get(schema_acc, "required", [])
          Map.put(schema_acc, "required", [Atom.to_string(name) | required])
        else
          schema_acc
        end
      end)

    # Store complete schema if referenced
    if ReferenceStore.has_reference?(store, schema) do
      ReferenceStore.add_definition(store, schema, schema_with_fields)
    end

    schema_with_fields
  end

  defp maybe_add_additional_properties(schema, strict) when is_boolean(strict) do
    Map.put(schema, "additionalProperties", not strict)
  end

  defp maybe_add_additional_properties(schema, _), do: schema

  defp convert_field_metadata(field_meta) do
    base = %{
      "description" => field_meta.description,
      "default" => field_meta.default,
      "readOnly" => field_meta.read_only
    }

    # Handle examples
    base =
      cond do
        examples = field_meta.examples ->
          Map.put(base, "examples", examples)

        example = field_meta.example ->
          Map.put(base, "examples", [example])

        true ->
          base
      end

    Map.reject(base, fn {_, v} -> is_nil(v) end)
  end
end
