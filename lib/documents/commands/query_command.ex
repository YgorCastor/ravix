defmodule Ravix.Documents.Commands.ExecuteQueryCommand do
  @derive {Jason.Encoder, only: [:Query, :QueryParameters]}
  use Ravix.Documents.Commands.RavenCommand,
    Query: nil,
    QueryParameters: %{}

  import Ravix.Documents.Commands.RavenCommand

  alias Ravix.Documents.Commands.ExecuteQueryCommand
  alias Ravix.Documents.Protocols.{ToJson, CreateRequest}
  alias Ravix.Connection.ServerNode

  command_type(%{
    Query: String.t(),
    QueryParameters: map()
  })

  defimpl CreateRequest, for: ExecuteQueryCommand do
    @spec create_request(ExecuteQueryCommand.t(), ServerNode.t()) :: ExecuteQueryCommand.t()
    def create_request(%ExecuteQueryCommand{} = command, %ServerNode{} = server_node) do
      url = server_node |> ServerNode.node_url()

      %ExecuteQueryCommand{
        command
        | url: url <> "/queries",
          data: fix_body(command)
      }
    end

    defp fix_body(command) do
      case command.method do
        "PATCH" -> %{Query: command} |> ToJson.to_json()
        _ -> command |> ToJson.to_json()
      end
    end
  end
end
