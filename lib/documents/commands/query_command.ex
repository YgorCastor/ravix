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
    QueryParameters: map(),
    query_hash: String.t()
  })

  defimpl CreateRequest, for: ExecuteQueryCommand do
    @spec create_request(ExecuteQueryCommand.t(), ServerNode.t()) :: ExecuteQueryCommand.t()
    def create_request(%ExecuteQueryCommand{} = command, %ServerNode{} = server_node) do
      url = server_node |> ServerNode.node_database_path()
      query_hash = hash_query(command[:Query], command[:QueryParameters])

      %ExecuteQueryCommand{
        command
        | url: url <> "/queries",
          data: fix_body(command),
          query_hash: query_hash
      }
    end

    defp hash_query(query, query_params) do
      joined_params = Enum.join(query_params, ",")
      :crypto.hash(:sha256, query <> joined_params) |> Base.encode16()
    end

    defp fix_body(command) do
      case command.method do
        :patch -> %{Query: command} |> ToJson.to_json()
        _ -> command |> ToJson.to_json()
      end
    end
  end
end
