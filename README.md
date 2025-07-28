# Elixact

Elixact is a powerful schema definition and validation library for Elixir, inspired by Python's Pydantic.
It provides a rich DSL for defining schemas with strong type validation, automatic JSON Schema generation, and excellent developer experience.

## Features

- 🎯 **Rich Schema DSL** - Intuitive and expressive schema definitions
- 🔍 **Strong Type Validation** - Comprehensive validation for basic and complex types
- 📊 **JSON Schema Support** - Automatic generation of JSON Schema from your Elixir schemas
- 🧩 **Custom Types** - Easily define reusable custom types
- 🎄 **Nested Schemas** - Support for deeply nested data structures
- ⛓️ **Field Constraints** - Rich set of built-in constraints
- 🚨 **Structured Errors** - Clear and actionable error messages

## Installation

Add `elixact` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:elixact, "~> 0.1.0"}
  ]
end
```

## Quick Start

### Basic Schema Definition

```elixir
defmodule UserSchema do
  use Elixact

  schema "User account information" do
    field :name, :string do
      description "User's full name"
      min_length 2
      max_length 50
    end

    field :age, :integer do
      description "User's age"
      gt 0
      lt 150
      optional()
    end

    field :email, :string do
      format ~r/^[^\s]+@[^\s]+$/
    end

    field :tags, {:array, :string} do
      description "User tags"
      min_items 0
      max_items 5
      default []
    end

    config do
      title "User Schema"
      strict true
    end
  end
end
```

### Data Validation

```elixir
# Validate data
case UserSchema.validate(%{
  name: "John Doe",
  email: "john@example.com",
  age: 30,
  tags: ["admin"]
}) do
  {:ok, validated_data} ->
    # Use validated data
    IO.inspect(validated_data)

  {:error, errors} ->
    # Handle validation errors
    Enum.each(errors, &IO.puts(Elixact.Error.format(&1)))
end

# Or use bang version which raises on error
validated = UserSchema.validate!(data)
```

### Complex Types

```elixir
defmodule ComplexSchema do
  use Elixact

  schema do
    # Array of maps
    field :metadata, {:array, {:map, {:string, :any}}} do
      min_items 1
      description "Metadata entries"
    end

    # Union type
    field :id, {:union, [:string, :integer]} do
      description "User ID (string or integer)"
    end

    # Nested schema
    field :address, AddressSchema do
      optional()
    end

    # Map with specific key/value types
    field :settings, {:map, {:string, {:union, [:string, :boolean, :integer]}}} do
      description "User settings"
      default %{}
    end
  end
end
```

### Custom Types

```elixir
defmodule Types.Email do
  use Elixact.Type

  def type_definition do
    Elixact.Types.string()
    |> Elixact.Types.with_constraints([
      format: ~r/^[^\s]+@[^\s]+$/
    ])
  end

  def json_schema do
    %{
      "type" => "string",
      "format" => "email",
      "pattern" => "^[^\\s]+@[^\\s]+$"
    }
  end
end
```

### Struct generation
```elixir
defmodule User do
  use Elixact

  schema do
    field :name, :string do
      required()
    end

    field :age, :integer do
      optional()
    end

    config do
      use_struct(true)
    end
  end
end

validated = User.validate(data)
is_struct(validate, User)
# true
```

### JSON Schema Generation

```elixir
# Generate JSON Schema
json_schema = Elixact.JsonSchema.from_schema(UserSchema)

# The schema can be used with any JSON Schema validator
json = Jason.encode!(json_schema)
```

## Available Types

- Basic Types: `:string`, `:integer`, `:float`, `:boolean`, `:any`
- Complex Types:
  - Arrays: `{:array, type}`
  - Maps: `{:map, {key_type, value_type}}`
  - Unions: `{:union, [type1, type2, ...]}`
  - Custom Types: Any module implementing `Elixact.Type` behaviour
  - Nested Schemas: References to other schema modules

## Field Constraints

- Strings: `min_length`, `max_length`, `format` (regex)
- Numbers: `gt`, `lt`, `gteq`, `lteq`
- Arrays: `min_items`, `max_items`
- General: `required`, `optional`, `default`, `choices`

## Error Handling

Elixact provides structured error messages with path information:

```elixir
{:error, [
  %Elixact.Error{
    path: [:email],
    code: :format,
    message: "invalid email format"
  }
]}
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
