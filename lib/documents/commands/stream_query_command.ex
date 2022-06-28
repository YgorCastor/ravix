defmodule Ravix.Documents.Commands.ExecuteStreamQueryCommand do
  @moduledoc """
  Command to execute a query on RavenDB

  ## Fields
  - Query: the RQL to be executed
  - QueryParameters: The query parameters
  """
  @derive {Jason.Encoder, only: [:Query, :QueryParameters]}
  use Ravix.Documents.Commands.RavenCommand,
    Query: nil,
    QueryParameters: %{}

  import Ravix.Documents.Commands.RavenCommand

  alias Ravix.Documents.Commands.ExecuteStreamQueryCommand
  alias Ravix.Documents.Protocols.CreateRequest
  alias Ravix.Connection.ServerNode

  command_type(%{
    Query: String.t(),
    QueryParameters: %{binary() => binary()}
  })

  defimpl CreateRequest, for: ExecuteStreamQueryCommand do
    @spec create_request(ExecuteStreamQueryCommand.t(), ServerNode.t()) ::
            ExecuteStreamQueryCommand.t()
    def create_request(%ExecuteStreamQueryCommand{} = command, %ServerNode{} = server_node) do
      url = server_node |> ServerNode.node_url()

      %ExecuteStreamQueryCommand{
        command
        | url: build_url(url, command),
          is_stream: true
      }
    end

    defp build_url(url, command) do
      (url <> "/streams/queries?query=#{build_query(command)}") |> URI.encode()
    end

    defp build_query(command) do
      Enum.reduce(
        Map.get(command, :QueryParameters),
        Map.get(command, :Query),
        fn {param, value}, query ->
          String.replace(query, param, value)
        end
      )
    end
  end
end
