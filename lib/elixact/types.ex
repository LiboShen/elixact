defmodule Elixact.Types do
  @moduledoc """
  Core type system for Elixact schemas.

  Provides functions for defining and working with types:
  - Basic types (:string, :integer, :float, :boolean)
  - Complex types (arrays, maps, unions)
  - Type constraints
  - Type validation
  - Type coercion

  ## Basic Types

      # String type
      Types.string()

      # Integer type with constraints
      Types.integer()
      |> Types.with_constraints(gt: 0, lt: 100)

  ## Complex Types

      # Array of strings
      Types.array(Types.string())

      # Map with string keys and integer values
      Types.map(Types.string(), Types.integer())

      # Union of types
      Types.union([Types.string(), Types.integer()])

  ## Type Constraints

  Constraints can be added to types to enforce additional rules:

      Types.string()
      |> Types.with_constraints([
        min_length: 3,
        max_length: 10,
        format: ~r/^[a-z]+$/
      ])
  """

  @type type_definition ::
          {:type, atom(), [any()]}
          | {:array, type_definition, [any()]}
          | {:map, {type_definition, type_definition}, [any()]}
          | {:union, [type_definition], [any()]}
          | {:ref, atom()}

  alias Elixact.Error

  # Basic types
  def string, do: {:type, :string, []}
  def integer, do: {:type, :integer, []}
  def float, do: {:type, :float, []}
  def boolean, do: {:type, :boolean, []}

  # Basic type constructor
  def type(name) when is_atom(name) do
    case name do
      :string -> string()
      :integer -> integer()
      :float -> float()
      :boolean -> boolean()
      _ -> {:type, name, []}
    end
  end

  # Complex types
  def array(inner_type) do
    normalized = normalize_type(inner_type)
    {:array, normalized, []}
  end

  def map(key_type, value_type) do
    normalized_key = normalize_type(key_type)
    normalized_value = normalize_type(value_type)
    {:map, {normalized_key, normalized_value}, []}
  end

  def union(types) when is_list(types), do: {:union, types, []}
  # Type reference
  def ref(schema), do: {:ref, schema}

  # Helper to normalize type definitions
  def normalize_type({:map, {key_type, value_type}}) do
    {:map, {normalize_type(key_type), normalize_type(value_type)}, []}
  end

  def normalize_type({:union, types}) when is_list(types) do
    {:union, Enum.map(types, &normalize_type/1), []}
  end

  def normalize_type(type) when is_atom(type) do
    case type do
      type when type in [:string, :integer, :float, :boolean, :any] ->
        {:type, type, []}

      other ->
        if match?({:module, _}, Code.ensure_compiled(other)) &&
             function_exported?(other, :type_definition, 0) do
          other.type_definition()
        else
          # Assume schema module reference
          {:ref, other}
        end
    end
  end

  def normalize_type(other), do: other

  # Add coercion helpers
  def coerce(:string, value) when is_integer(value), do: {:ok, Integer.to_string(value)}
  def coerce(:string, value) when is_float(value), do: {:ok, Float.to_string(value)}

  def coerce(:integer, value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> {:error, "invalid integer format"}
    end
  end

  def coerce(:float, value) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> {:ok, float}
      _ -> {:error, "invalid float format"}
    end
  end

  def coerce(_, value), do: {:error, "cannot coerce #{inspect(value)}"}

  # Type constraints
  def with_constraints(type, constraints) do
    case type do
      {:type, name, existing} -> {:type, name, existing ++ constraints}
      {kind, inner, existing} -> {kind, inner, existing ++ constraints}
    end
  end

  # Validation functions
  def validate(:string, value) when is_binary(value), do: {:ok, value}

  def validate(:string, value),
    do: {:error, Error.new([], :type, "expected string, got #{inspect(value)}")}

  def validate(:integer, value) when is_integer(value), do: {:ok, value}

  def validate(:integer, value),
    do: {:error, Error.new([], :type, "expected integer, got #{inspect(value)}")}

  def validate(:float, value) when is_float(value), do: {:ok, value}

  def validate(:float, value),
    do: {:error, Error.new([], :type, "expected float, got #{inspect(value)}")}

  def validate(:boolean, value) when is_boolean(value), do: {:ok, value}

  def validate(:boolean, value),
    do: {:error, Error.new([], :type, "expected boolean, got #{inspect(value)}")}

  def validate(:any, value), do: {:ok, value}

  def validate(type, value) do
    {:error, Error.new([], :type, "#{inspect(value)} is not a valid #{inspect(type)}")}
  end
end
