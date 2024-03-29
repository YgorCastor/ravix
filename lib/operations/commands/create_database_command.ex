defmodule Ravix.Operations.Database.Commands.CreateDatabaseCommand do
  @moduledoc """
  Command to create a RavenDB database

  ## Fields
  - Disabled: true/false - If the database is created disabled as default
  - Encrypted: true/false - If the database is encrypted as default
  - DatabaseName: Name - the database name
  - ReplicationFactor: int - the replication factor of the database
  """
  @derive {Jason.Encoder, only: [:Disabled, :Encrypted, :DatabaseName]}
  use Ravix.Documents.Commands.RavenCommand,
    Disabled: false,
    Encrypted: false,
    DatabaseName: nil,
    ReplicationFactor: 1

  import Ravix.Documents.Commands.RavenCommand
  import Ravix.Helpers.UrlBuilder

  alias Ravix.Operations.Database.Commands.CreateDatabaseCommand
  alias Ravix.Documents.Protocols.{ToJson, CreateRequest}
  alias Ravix.Connection.ServerNode

  command_type(%{
    Disabled: boolean(),
    Encrypted: boolean(),
    DatabaseName: String.t(),
    ReplicationFactor: non_neg_integer()
  })

  defimpl CreateRequest, for: CreateDatabaseCommand do
    @spec create_request(CreateDatabaseCommand.t(), ServerNode.t()) :: CreateDatabaseCommand.t()
    def create_request(%CreateDatabaseCommand{} = command, %ServerNode{} = _server_node) do
      %CreateDatabaseCommand{
        command
        | url:
            "/admin/databases?"
            |> append_param("name", Map.get(command, "DatabaseName"))
            |> append_param("replicationFactor", Map.get(command, "ReplicationFactor")),
          method: :put,
          data: command |> ToJson.to_json()
      }
    end
  end
end
