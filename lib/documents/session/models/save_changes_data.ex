defmodule Ravix.Documents.Session.SaveChangesData do
  @moduledoc """
  Defines all changes that will be executed in a session when calling the save_changes function

  ## Fields
  - deferred_commands_count: How many command will be executed
  - commands: List of commands to be executed
  - entities: Entities in the current session
  """
  defstruct deferred_commands_count: 0,
            commands: [],
            entities: []

  alias Ravix.Documents.Session.SaveChangesData
  alias Ravix.Documents.Commands.Data.DeleteDocument
  alias Ravix.Documents.Commands.Data.PutDocument

  @type t :: %SaveChangesData{
          deferred_commands_count: non_neg_integer(),
          commands: list(map()),
          entities: list(map())
        }

  @doc """
  Add the commands that will be deferred to be executed together with the save_changes call

  ## Parameters
  - save_changes_data: this structure instance
  - deferred_commands: Raven commands to be deferred

  ## Returns
  - Updated `Ravix.Documents.Session.SaveChangesData`
  """
  @spec add_deferred_commands(SaveChangesData.t(), list(map())) :: SaveChangesData.t()
  def add_deferred_commands(%SaveChangesData{} = save_changes_data, deferred_commands) do
    %SaveChangesData{
      save_changes_data
      | commands: save_changes_data.commands ++ deferred_commands,
        deferred_commands_count: Enum.count(deferred_commands)
    }
  end

  @doc """
  Add the entities that will be deleted

  ## Parameters
  - save_changes_data: this structure instance
  - deleted_entities: Entities that will be deleted

  ## Returns
  - Updated `Ravix.Documents.Session.SaveChangesData`
  """
  @spec add_delete_commands(SaveChangesData.t(), list(map())) :: SaveChangesData.t()
  def add_delete_commands(%SaveChangesData{} = save_changes_data, deleted_entities) do
    delete_commands =
      Enum.map(
        deleted_entities,
        fn entity ->
          %DeleteDocument{Id: entity.key, ChangeVector: entity.change_vector}
        end
      )

    %SaveChangesData{
      save_changes_data
      | entities: save_changes_data.entities ++ deleted_entities,
        commands: save_changes_data.commands ++ delete_commands
    }
  end

  @doc """
  Adds the documents that will be created

  ## Parameters
  - save_changes_data: this structure instance
  - documents_by_id: Map with the documents that will be created

  ## Returns
  - Updated `Ravix.Documents.Session.SaveChangesData`
  """
  @spec add_put_commands(SaveChangesData.t(), map()) :: SaveChangesData.t()
  def add_put_commands(%SaveChangesData{} = save_changes_data, documents_by_id) do
    put_commands =
      documents_by_id
      |> Map.values()
      |> documents_with_changes()
      |> Enum.map(fn elmn ->
        %PutDocument{Id: elmn.key, Document: elmn.entity, ChangeVector: elmn.change_vector}
      end)

    entities = put_commands |> Enum.map(fn cmnd -> Map.get(cmnd, "Document") end)

    %SaveChangesData{
      save_changes_data
      | entities: save_changes_data.entities ++ entities,
        commands: save_changes_data.commands ++ put_commands
    }
  end

  defp documents_with_changes(documents_by_id) do
    Enum.filter(documents_by_id, fn document ->
      document.entity != document.original_value
    end)
  end
end
