defmodule Ravix.Documents.Commands.BatchCommand do
  @derive {Jason.Encoder, only: [:Commands]}
  use Ravix.Documents.Commands.RavenCommand,
    Commands: []

  import Ravix.Documents.Commands.RavenCommand

  alias Ravix.Documents.Protocols.{CreateRequest, ToJson}
  alias Ravix.Documents.Commands.BatchCommand
  alias Ravix.Connection.ServerNode

  command_type(%{
    Commands: list(map())
  })

  defimpl CreateRequest, for: BatchCommand do
    @spec create_request(BatchCommand.t(), ServerNode.t()) :: BatchCommand.t()
    def create_request(command = %BatchCommand{}, server_node = %ServerNode{}) do
      url = server_node |> ServerNode.node_url()

      %BatchCommand{
        command
        | url: url <> "/bulk_docs",
          method: "POST",
          data: command |> ToJson.to_json()
      }
    end
  end
end
