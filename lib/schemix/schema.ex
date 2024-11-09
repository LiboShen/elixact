defmodule Schemix.Schema do
  @moduledoc """
  Schema DSL for defining data schemas with validation rules and metadata.
  """

  alias Schemix.Types

  defmacro schema(description \\ nil, do: block) do
    quote do
      Module.register_attribute(__MODULE__, :fields, accumulate: true)
      Module.register_attribute(__MODULE__, :config, [])

      @schema_description unquote(description)

      unquote(block)

      # Generate schema metadata at compile time
      def __schema__(:description), do: @schema_description
      def __schema__(:fields), do: @fields
      def __schema__(:config), do: @config

      # Generate validation functions
      def validate(data) do
        Schemix.Validator.validate_schema(__MODULE__, data)
      end

      def validate!(data) do
        case validate(data) do
          {:ok, validated} -> validated
          {:error, errors} -> raise Schemix.ValidationError, errors: errors
        end
      end
    end
  end

  defmacro field(name, type, do: block) do
    quote do
      field_meta = %{
        name: unquote(name),
        type: unquote(handle_type(type)),
        description: nil,
        example: nil,
        required: false,
        optional: false,
        default: nil,
        constraints: []
      }

      var!(field_meta) = field_meta
      unquote(block)

      @fields {unquote(name), var!(field_meta)}
    end
  end

  # Field metadata setters
  defmacro description(text) do
    quote do
      var!(field_meta) = Map.put(var!(field_meta), :description, unquote(text))
    end
  end

  defmacro example(value) do
    quote do
      var!(field_meta) = Map.put(var!(field_meta), :example, unquote(value))
    end
  end

  defmacro examples(values) when is_list(values) do
    quote do
      var!(field_meta) = Map.put(var!(field_meta), :examples, unquote(values))
    end
  end

  defmacro required(bool) do
    quote do
      var!(field_meta) = Map.put(var!(field_meta), :required, unquote(bool))
    end
  end

  defmacro optional(bool) do
    quote do
      var!(field_meta) =
        var!(field_meta)
        |> Map.put(:optional, unquote(bool))
        |> Map.put(:required, not unquote(bool))
    end
  end

  defmacro default(value) do
    quote do
      var!(field_meta) = Map.put(var!(field_meta), :default, unquote(value))
    end
  end

  # Handle type definitions
  defp handle_type({:array, type}) do
    quote do
      Types.array(unquote(type))
    end
  end

  defp handle_type({:map, {key_type, value_type}}) do
    quote do
      Types.map(unquote(key_type), unquote(value_type))
    end
  end

  defp handle_type({:union, types}) do
    quote do
      Types.union(unquote(types))
    end
  end

  defp handle_type({:__aliases__, _, _} = module_alias) do
    quote do
      unquote(module_alias)
    end
  end

  defp handle_type(type) when is_atom(type) do
    quote do
      Types.type(unquote(type))
    end
  end

  # Configuration block
  defmacro config(do: block) do
    quote do
      config = %{
        title: nil,
        description: nil,
        strict: false
      }

      var!(config) = config
      unquote(block)

      @config var!(config)
    end
  end

  # Config setters
  defmacro title(text) do
    quote do
      var!(config) = Map.put(var!(config), :title, unquote(text))
    end
  end

  defmacro config_description(text) do
    quote do
      var!(config) = Map.put(var!(config), :description, unquote(text))
    end
  end

  defmacro strict(bool) do
    quote do
      var!(config) = Map.put(var!(config), :strict, unquote(bool))
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def __schema__(:description), do: @schema_description
      def __schema__(:fields), do: @fields
      def __schema__(:validations), do: @validations
      def __schema__(:config), do: @config

      @doc """
      Validates data against this schema.

      Returns `{:ok, validated_data}` or `{:error, errors}`.
      """
      def validate(data) do
        Schemix.Validator.validate_schema(__MODULE__, data)
      end

      @doc """
      Validates data against this schema, raising on error.

      Returns validated data or raises Schemix.ValidationError.
      """
      def validate!(data) do
        case validate(data) do
          {:ok, validated} -> validated
          {:error, errors} -> raise Schemix.ValidationError, errors: errors
        end
      end
    end
  end
end