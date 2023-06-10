defmodule Ravix.Documents.Commands.ExecuteQueryCommand do
  @moduledoc """
  Command to execute a queryy on RavenDB

  ## Fields
  - Query: the RQL to be executed
  - QueryParameters: The query parameters
  """
  @derive {Jason.Encoder, only: [:Query, :QueryParameters]}
  use Ravix.Documents.Commands.RavenCommand,
    Query: nil,
    QueryParameters: %{},
    query_hash: nil

  import Ravix.Documents.Commands.RavenCommand

  alias Ravix.Documents.Commands.ExecuteQueryCommand
  alias Ravix.Documents.Protocols.{ToJson, CreateRequest}
  alias Ravix.Connection.ServerNode

  command_type(%{
    Query: String.t(),
    QueryParameters: map()
  })

  def hash_query(%ExecuteQueryCommand{Query: query, QueryParameters: query_params}) do
    joined_params = Enum.join(query_params, ",")
    :crypto.hash(:sha256, query <> joined_params) |> Base.encode16()
  end

  defimpl CreateRequest, for: ExecuteQueryCommand do
    @spec create_request(ExecuteQueryCommand.t(), ServerNode.t()) :: ExecuteQueryCommand.t()
    def create_request(%ExecuteQueryCommand{} = command, %ServerNode{} = server_node) do
      url = server_node |> ServerNode.node_database_path()

      %ExecuteQueryCommand{
        command
        | url: url <> "/queries",
          data: fix_body(command)
      }
    end

    defp fix_body(command) do
      case command.method do
        :patch -> %{Query: command} |> ToJson.to_json()
        _ -> command |> ToJson.to_json()
      end
    end
  end
end
