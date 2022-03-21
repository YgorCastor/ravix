defmodule Ravix.Database.Commands.GetDatabaseCommand do
  use Ravix.Documents.Commands.RavenCommand,
    databaseName: nil

  import Ravix.Documents.Commands.RavenCommand
  import Ravix.Helpers.UrlBuilder

  alias Ravix.Database.Commands.GetDatabaseCommand
  alias Ravix.Documents.Protocols.CreateRequest
  alias Ravix.Connection.ServerNode

  command_type(%{
    databaseName: String.t() | nil
  })

  defimpl CreateRequest, for: GetDatabaseCommand do
    @spec create_request(GetDatabaseCommand.t(), ServerNode.t()) :: GetDatabaseCommand.t()
    def create_request(%GetDatabaseCommand{} = command, %ServerNode{} = _server_node) do
      %GetDatabaseCommand{
        command
        | url:
            "/databases"
            |> append_param("name", command.databaseName)
      }
    end
  end
end
