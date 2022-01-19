defmodule Ravix.Documents.Session.StateTest do
  use ExUnit.Case

  import Ravix.Factory

  alias Ravix.Documents.Session.State

  describe "increment_request_count/1" do
    test "should increase by 1" do
      state = build(:session_state)
      updated_state = State.increment_request_count(state)

      assert state.number_of_requests + 1 == updated_state.number_of_requests
    end
  end

  describe "register_document/4" do
    test "if the entity is in a deferred command, return an :document_already_deferred error" do
      state = build(:session_state)
      entity = %{id: Enum.at(state.defer_commands, 0).key}

      {:error, :document_already_deferred} =
        State.register_document(state, entity.id, entity, "", %{}, %{}, nil)
    end

    test "if the document is deleted, return an :document_deleted error" do
      state = build(:session_state)
      entity = %{id: Enum.at(state.deleted_entities, 0).id}

      {:error, :document_deleted} =
        State.register_document(state, entity.id, entity, "", %{}, %{}, nil)
    end

    test "if the document already exists, return an :document_already_stored error" do
      state = build(:session_state)
      keys = Map.keys(state.documents_by_id)
      entity = %{id: Enum.at(keys, 0)}

      {:error, :document_already_stored} =
        State.register_document(state, entity.id, entity, "", %{}, %{}, nil)
    end

    test "if no error occurs, return the updated state with a new document" do
      state = build(:session_state)
      entity = %{id: "any_id"}

      {:ok, updated_state = %State{}} =
        State.register_document(state, entity.id, entity, "", %{}, %{}, nil)

      assert Map.has_key?(updated_state.documents_by_id, "any_id") == true
    end
  end
end
