defmodule Ravix.Operations.Database.Commands.GetStatisticsCommand do
  @moduledoc """
  Command to delete a RavenDB database
  """
  @derive {Jason.Encoder, only: [:debugTag]}
  use Ravix.Documents.Commands.RavenCommand,
    debugTag: nil

  import Ravix.Documents.Commands.RavenCommand

  alias Ravix.Operations.Database.Commands.GetStatisticsCommand
  alias Ravix.Documents.Protocols.CreateRequest
  alias Ravix.Connection.ServerNode

  command_type(%{
    debugTag: String.t()
  })

  defimpl CreateRequest, for: GetStatisticsCommand do
    @spec create_request(GetStatisticsCommand.t(), ServerNode.t()) :: GetStatisticsCommand.t()
    def create_request(%GetStatisticsCommand{} = command, %ServerNode{} = server_node) do
      %GetStatisticsCommand{
        command
        | url: "/databases/#{server_node.database}/stats?" <> command.debugTag,
          method: "GET"
      }
    end
  end
end
