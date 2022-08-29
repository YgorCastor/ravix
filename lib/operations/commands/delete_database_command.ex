defmodule Ravix.Operations.Database.Commands.DeleteDatabaseCommand do
  @moduledoc """
  Command to delete a RavenDB database
  """
  @derive {Jason.Encoder, only: [:DatabaseNames, :HardDelete, :TimeToWaitForConfirmation]}
  use Ravix.Documents.Commands.RavenCommand,
    DatabaseNames: [],
    HardDelete: false,
    TimeToWaitForConfirmation: nil

  import Ravix.Documents.Commands.RavenCommand

  alias Ravix.Operations.Database.Commands.DeleteDatabaseCommand
  alias Ravix.Documents.Protocols.{ToJson, CreateRequest}
  alias Ravix.Connection.ServerNode

  command_type(%{
    DatabaseNames: list(String.t()),
    HardDelete: boolean(),
    TimeToWaitForConfirmation: non_neg_integer()
  })

  defimpl CreateRequest, for: DeleteDatabaseCommand do
    @spec create_request(DeleteDatabaseCommand.t(), ServerNode.t()) :: DeleteDatabaseCommand.t()
    def create_request(%DeleteDatabaseCommand{} = command, %ServerNode{} = _server_node) do
      %DeleteDatabaseCommand{
        command
        | url: "/admin/databases",
          method: :delete,
          data: command |> ToJson.to_json()
      }
    end
  end
end
