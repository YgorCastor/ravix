defmodule Ravix.Documents.Commands.BatchCommand do
  @derive {Jason.Encoder, only: [:Commands]}
  use Ravix.Documents.Commands.RavenCommand,
    Commands: []

  import Ravix.Documents.Commands.RavenCommand

  alias Ravix.Documents.Protocols.{CreateRequest, ToJson}
  alias Ravix.Documents.Commands.BatchCommand
  alias Ravix.Documents.Session
  alias Ravix.Connection.ServerNode

  command_type(%{
    Commands: list(map())
  })

  @spec parse_batch_response(map(), Session.State.t()) :: list
  def parse_batch_response(batch_response, session_state) do
    batch_response
    |> Enum.map(fn batch_item -> parse_batch_item(batch_item, session_state) end)
  end

  defp parse_batch_item(batch_item, session_state) when is_map_key(batch_item, "Type") do
    case batch_item["Type"] do
      "PUT" -> {:ok, :update_document, update_document(session_state, batch_item)}
      action_type -> {:error, :not_implemented, action_type}
    end
  end

  defp update_document(session_state, document) when is_map_key(document, "@id") do
    case Session.State.fetch_document(session_state, document["@id"]) do
      existing_document when existing_document != nil ->
        %{
          existing_document
          | change_vector: document["@change-vector"],
            original_metadata: existing_document.metadata,
            original_value: existing_document.entity
        }

      _ ->
        nil
    end
  end

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
