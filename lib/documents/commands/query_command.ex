defmodule Ravix.Documents.Commands.ExecuteQueryCommand do
  @derive {Jason.Encoder, only: [:Query, :QueryParameters]}
  use Ravix.Documents.Commands.RavenCommand,
    Query: nil,
    QueryParameters: %{}

  alias Ravix.Documents.Commands.ExecuteQueryCommand
  alias Ravix.Documents.Protocols.{ToJson, CreateRequest}
  alias Ravix.Connection.ServerNode

  defimpl CreateRequest, for: ExecuteQueryCommand do
    @spec create_request(ExecuteQueryCommand.t(), ServerNode.t()) :: ExecuteQueryCommand.t()
    def create_request(command = %ExecuteQueryCommand{}, server_node = %ServerNode{}) do
      url = server_node |> ServerNode.node_url()

      %ExecuteQueryCommand{
        command
        | url: url <> "/queries",
          method: "POST",
          data: command |> ToJson.to_json()
      }
    end
  end
end
