defmodule Ravix.Documents.Commands.BatchCommand do
  @moduledoc """
  Raven Command to execute actions in batches

  ## Fields
  - Commands: list of raven commands to be executed
  """
  @derive {Jason.Encoder, only: [:Commands]}
  use Ravix.Documents.Commands.RavenCommand,
    Commands: []

  import Ravix.Documents.Commands.RavenCommand

  alias Ravix.Documents.Protocols.{CreateRequest, ToJson}
  alias Ravix.Documents.Commands.BatchCommand
  alias Ravix.Documents.Session.{State, SessionDocument}
  alias Ravix.Connection.ServerNode

  command_type(%{
    Commands: list(map())
  })

  @doc """
  Parses the response of a batch request

  ## Parameters
  - batch_response: The RavenDB batch response. 
  - session_state: The state of the session where the command was executed.
  """
  @spec parse_batch_response(map(), State.t()) :: list
  def parse_batch_response(batch_response, session_state) do
    batch_response
    |> Enum.map(fn batch_item -> parse_batch_item(batch_item, session_state) end)
  end

  defp parse_batch_item(batch_item, session_state) when is_map_key(batch_item, "Type") do
    case batch_item["Type"] do
      "PUT" ->
        {:ok, :update_document, SessionDocument.upsert_document(session_state, batch_item)}

      "DELETE" ->
        {:ok, :delete_document, batch_item["Id"]}

      action_type ->
        {:error, :not_implemented, action_type}
    end
  end

  defimpl CreateRequest, for: BatchCommand do
    @spec create_request(BatchCommand.t(), ServerNode.t()) :: BatchCommand.t()
    def create_request(%BatchCommand{} = command, %ServerNode{} = server_node) do
      url = server_node |> ServerNode.node_url()

      %BatchCommand{
        command
        | url: url <> "/bulk_docs",
          method: :post,
          data: command |> ToJson.to_json()
      }
    end
  end
end
