defmodule Schemix.IntegrationTest do
  use ExUnit.Case, async: true

  # Custom Email type for testing
  defmodule EmailType do
    use Schemix.Type

    def type_definition do
      Schemix.Types.string()
      |> Schemix.Types.with_constraints([
        {:format, ~r/^[^\s]+@[^\s]+$/}
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

  # Address schema for nested schema testing
  defmodule AddressSchema do
    use Schemix

    schema "Address information" do
      field :street, :string do
        min_length(5)
      end

      field :city, :string do
      end

      field :postal_code, :string do
        format(~r/^\d{5}$/)
      end

      field :country, :string do
        default("USA")
      end
    end
  end

  # Main test schema with various field types and validations
  defmodule UserSchema do
    use Schemix

    schema "User account information" do
      field :email, EmailType do
        description("User's email address")
      end

      field :username, :string do
        min_length(3)
        max_length(20)
        format(~r/^[a-zA-Z0-9_]+$/)
      end

      field :age, :integer do
        optional()
        gt(0)
        lt(150)
      end

      field :height, :float do
        optional()
        gteq(0.0)
        lteq(3.0)
      end

      field :is_active, :boolean do
        default(true)
      end

      field :tags, {:array, :string} do
        description("User tags")
        default([])
        min_items(0)
        max_items(5)
      end

      field :address, AddressSchema do
        optional()
      end

      field :settings, {:map, {:string, {:union, [:string, :boolean, :integer]}}} do
        description("User settings")
        optional()
      end

      config do
        title("User Schema")
        config_description("Complete user profile schema")
        strict(true)
      end
    end
  end

  describe "schema validation" do
    test "validates complete valid data" do
      valid_data = %{
        email: "test@example.com",
        username: "john_doe",
        age: 25,
        height: 1.75,
        is_active: true,
        tags: ["user", "premium"],
        address: %{
          street: "123 Main Street",
          city: "Springfield",
          postal_code: "12345",
          country: "USA"
        },
        settings: %{
          "theme" => "dark",
          "notifications" => true,
          "max_items" => 100
        }
      }

      assert {:ok, validated} = UserSchema.validate(valid_data)
      assert validated.email == "test@example.com"
      assert validated.username == "john_doe"
    end

    test "validates minimal valid data" do
      valid_data = %{
        email: "test@example.com",
        username: "john_doe",
        is_active: true
      }

      assert {:ok, validated} = UserSchema.validate(valid_data)
      assert validated.is_active == true
      # default value
      assert validated.tags == []
    end

    test "rejects invalid email" do
      invalid_data = %{
        email: "not-an-email",
        username: "john_doe",
        is_active: true
      }

      assert {:error, error} = UserSchema.validate(invalid_data)
      assert error.message =~ "format"
    end

    test "rejects invalid username format" do
      invalid_data = %{
        email: "test@example.com",
        # contains invalid character
        username: "john@doe",
        is_active: true
      }

      assert {:error, error} = UserSchema.validate(invalid_data)
      assert error.message =~ "format"
    end

    test "rejects invalid nested address data" do
      invalid_data = %{
        email: "test@example.com",
        username: "john_doe",
        is_active: true,
        address: %{
          # too short
          street: "123",
          city: "Springfield",
          # invalid format
          postal_code: "1234",
          country: "USA"
        }
      }

      assert {:error, error} = UserSchema.validate(invalid_data)

      assert error == %Schemix.Error{
               path: [:address, :postal_code],
               code: :format,
               message: "failed format constraint"
             }
    end

    test "rejects additional properties when strict" do
      invalid_data = %{
        email: "test@example.com",
        username: "john_doe",
        is_active: true,
        unknown_field: "value"
      }

      assert {:error, error} = UserSchema.validate(invalid_data)
      assert error.message =~ "unknown_field"
    end
  end

  describe "JSON Schema generation" do
    test "generates valid JSON Schema" do
      schema = Schemix.JsonSchema.from_schema(UserSchema)

      assert schema["title"] == "User Schema"
      assert schema["type"] == "object"
      assert schema["additionalProperties"] == false

      # Check properties
      assert Map.has_key?(schema["properties"], "email")
      assert Map.has_key?(schema["properties"], "username")
      assert Map.has_key?(schema["properties"], "address")

      # Check nested schema
      assert schema["definitions"]["AddressSchema"]
      assert schema["properties"]["address"]["$ref"] == "#/definitions/AddressSchema"
    end
  end
end
