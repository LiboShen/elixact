defmodule Elixact.FieldMeta do
  @moduledoc """
  Struct for field metadata
  """

  defstruct [
    :name,
    :type,
    :description,
    :example,
    :examples,
    :required,
    :optional,
    :default,
    :constraints,
    :read_only
  ]
end
