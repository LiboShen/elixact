defmodule Elixact.Type do
  @moduledoc """
  Behaviour and macros for defining custom types.
  """

  @callback type_definition() :: Elixact.Types.type_definition()
  @callback json_schema() :: map()
  @callback validate(term()) :: {:ok, term()} | {:error, term()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Elixact.Type
      import Elixact.Types

      Module.register_attribute(__MODULE__, :type_metadata, accumulate: true)

      def metadata, do: @type_metadata

      def validate(value, path \\ []) do
        with {:ok, coerced} <- maybe_coerce(value),
             {:ok, validated} <- validate_type(coerced, path) do
          validate_custom_rules(validated, path)
        end
      end

      defp validate_type(value, path) do
        type = type_definition()
        Elixact.Validator.validate(type, value, path)
      end

      defp maybe_coerce(value) do
        case coerce_rule() do
          nil -> {:ok, value}
          rule when is_function(rule) -> rule.(value)
          {module, function} -> apply(module, function, [value])
        end
      end

      defp validate_custom_rules(value, path) do
        Enum.reduce_while(custom_rules(), {:ok, value}, fn rule, {:ok, val} ->
          case apply(__MODULE__, rule, [val]) do
            true -> {:cont, {:ok, val}}
            false -> {:halt, {:error, "failed custom rule: #{rule}"}}
            {:error, reason} -> {:halt, {:error, reason, path: path}}
          end
        end)
      end

      # Default implementations that can be overridden
      def coerce_rule, do: Process.get(make_ref(), nil)
      def custom_rules, do: []

      defoverridable coerce_rule: 0, custom_rules: 0
    end
  end
end
