defmodule Ravix.Operations.Database.Commands.GetStatisticsCommand do
  @moduledoc """
  Command to delete a RavenDB database
  """
  @derive {Jason.Encoder, only: [:debugTag]}
  use Ravix.Documents.Commands.RavenCommand,
    debugTag: nil,
    databaseName: nil

  import Ravix.Documents.Commands.RavenCommand

  alias Ravix.Operations.Database.Commands.GetStatisticsCommand
  alias Ravix.Documents.Protocols.CreateRequest
  alias Ravix.Connection.ServerNode

  command_type(%{
    debugTag: String.t(),
    databaseName: String.t() | nil
  })

  defimpl CreateRequest, for: GetStatisticsCommand do
    @spec create_request(GetStatisticsCommand.t(), ServerNode.t()) :: GetStatisticsCommand.t()
    def create_request(%GetStatisticsCommand{} = command, %ServerNode{} = server_node) do
      database_name =
        case command.databaseName do
          nil -> server_node.database
          database_name -> database_name
        end

      %GetStatisticsCommand{
        command
        | url: "/databases/#{database_name}/stats?" <> command.debugTag,
          method: :get
      }
    end
  end
end
