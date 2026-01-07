defmodule Elixact.JsonSchemaTest do
  use ExUnit.Case, async: true

  describe "basic schema conversion" do
    defmodule MetadataSchema do
      use Elixact

      schema "Schema with rich metadata" do
        field :name, :string do
          description("User's name")
          example("John Doe")
        end

        field :age, :integer do
          description("User's age")
          optional()
          default(18)
        end

        field :tags, {:array, :string} do
          description("User tags")
          examples(["admin", "user"])
          default([])
        end

        field :created_at, :integer do
          description("Timestamp of user creation.")
          optional()
          read_only()
        end
      end
    end

    test "converts schema with rich metadata" do
      expected = %{
        "type" => "object",
        "description" => "Schema with rich metadata",
        "properties" => %{
          "name" => %{
            "type" => "string",
            "description" => "User's name",
            "examples" => ["John Doe"]
          },
          "age" => %{
            "type" => "integer",
            "description" => "User's age",
            "default" => 18
          },
          "tags" => %{
            "type" => "array",
            "items" => %{"type" => "string"},
            "description" => "User tags",
            "examples" => ["admin", "user"],
            "default" => []
          },
          "created_at" => %{
            "description" => "Timestamp of user creation.",
            "type" => "integer",
            "readOnly" => true
          }
        },
        "required" => ["name"]
      }

      assert Elixact.JsonSchema.from_schema(MetadataSchema) == expected
    end
  end

  describe "schema configuration" do
    defmodule ConfiguredSchema do
      use Elixact

      schema "Configured schema" do
        field :name, :string do
        end

        field :data, {:map, {:string, :string}} do
          optional()
        end

        config do
          title("User Configuration")
          config_description("Configuration for user data")
          strict(true)
        end
      end
    end

    test "includes configuration in schema" do
      expected = %{
        "type" => "object",
        "title" => "User Configuration",
        "description" => "Configuration for user data",
        "additionalProperties" => false,
        "properties" => %{
          "name" => %{
            "type" => "string"
          },
          "data" => %{
            "type" => "object",
            "additionalProperties" => %{"type" => "string"}
          }
        },
        "required" => ["name"]
      }

      assert Elixact.JsonSchema.from_schema(ConfiguredSchema) == expected
    end
  end

  describe "custom type handling" do
    defmodule EmailType do
      use Elixact.Type

      def type_definition do
        Elixact.Types.string()
        |> Elixact.Types.with_constraints([
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

    defmodule SchemaWithCustomTypes do
      use Elixact

      schema "Schema with custom types" do
        field :email, EmailType do
          description("User's email address")
        end

        field :backup_email, EmailType do
          optional()
          description("Backup email address")
        end
      end
    end

    test "handles custom types correctly" do
      expected = %{
        "type" => "object",
        "description" => "Schema with custom types",
        "properties" => %{
          "email" => %{
            "type" => "string",
            "format" => "email",
            "pattern" => "^[^\\s]+@[^\\s]+$",
            "description" => "User's email address"
          },
          "backup_email" => %{
            "type" => "string",
            "format" => "email",
            "pattern" => "^[^\\s]+@[^\\s]+$",
            "description" => "Backup email address"
          }
        },
        "required" => ["email"]
      }

      assert Elixact.JsonSchema.from_schema(SchemaWithCustomTypes) == expected
    end
  end

  describe "schema references" do
    defmodule AddressSchema do
      use Elixact

      schema "Address information" do
        field :street, :string do
        end

        field :city, :string do
        end

        field :country, :string do
        end
      end
    end

    defmodule ContactSchema do
      use Elixact

      schema "Contact information" do
        field :primary_address, AddressSchema do
        end

        field :shipping_address, AddressSchema do
          optional()
        end
      end
    end

    defmodule CircularSchema do
      use Elixact

      schema "Schema with circular reference" do
        field :name, :string do
        end

        field :parent, CircularSchema do
          optional()
        end

        field :children, {:array, CircularSchema} do
          optional()
        end
      end
    end

    test "handles schema references" do
      expected = %{
        "type" => "object",
        "description" => "Contact information",
        "properties" => %{
          "primary_address" => %{
            "$ref" => "#/definitions/AddressSchema"
          },
          "shipping_address" => %{
            "$ref" => "#/definitions/AddressSchema"
          }
        },
        "required" => ["primary_address"],
        "definitions" => %{
          "AddressSchema" => %{
            "type" => "object",
            "description" => "Address information",
            "properties" => %{
              "street" => %{"type" => "string"},
              "city" => %{"type" => "string"},
              "country" => %{"type" => "string"}
            },
            "required" => ["street", "city", "country"]
          }
        }
      }

      assert Elixact.JsonSchema.from_schema(ContactSchema) == expected
    end

    test "handles circular references" do
      expected = %{
        "type" => "object",
        "description" => "Schema with circular reference",
        "properties" => %{
          "name" => %{"type" => "string"},
          "parent" => %{"$ref" => "#/definitions/CircularSchema"},
          "children" => %{
            "type" => "array",
            "items" => %{"$ref" => "#/definitions/CircularSchema"}
          }
        },
        "required" => ["name"],
        "definitions" => %{
          "CircularSchema" => %{
            "type" => "object",
            "description" => "Schema with circular reference",
            "properties" => %{
              "name" => %{"type" => "string"},
              "parent" => %{"$ref" => "#/definitions/CircularSchema"},
              "children" => %{
                "type" => "array",
                "items" => %{"$ref" => "#/definitions/CircularSchema"}
              }
            },
            "required" => ["name"]
          }
        }
      }

      assert Elixact.JsonSchema.from_schema(CircularSchema) == expected
    end
  end
end
