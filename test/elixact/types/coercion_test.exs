defmodule Elixact.Types.CoercionTest do
  use ExUnit.Case, async: true
  alias Elixact.Types

  test "coerces string to integer" do
    assert {:ok, 123} = Types.coerce(:integer, "123")
    assert {:error, _} = Types.coerce(:integer, "abc")
  end

  test "coerces integer to string" do
    assert {:ok, "123"} = Types.coerce(:string, 123)
  end
end
