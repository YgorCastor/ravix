defmodule Ravix.Documents.SessionTest do
  use ExUnit.Case

  require OK

  alias Ravix.Documents.Session
  alias Ravix.Documents.Store

  setup do
    %{ravix: start_supervised!(Ravix)}
  end

  describe "store/3" do
    test "A document should be stored using the entity id" do
      any_entity = %{id: UUID.uuid4(), cat_name: Faker.Cat.name()}

      {:ok, result} =
        OK.for do
          session_id <- Store.open_session("test")
          stored_document <- Session.store(session_id, any_entity)
          session_state <- Session.fetch_state(session_id)
        after
          [stored_document: stored_document, session_state: session_state]
        end

      documents_in_state = result[:session_state].documents_by_id

      assert result[:stored_document] == any_entity
      assert Map.has_key?(documents_in_state, any_entity.id) == true
    end

    test "A document should be stored using a custom key successfully" do
      any_entity = %{id: UUID.uuid4(), cat_name: Faker.Cat.name()}

      {:ok, result} =
        OK.for do
          session_id <- Store.open_session("test")
          stored_document <- Session.store(session_id, any_entity, "custom_key")
          session_state <- Session.fetch_state(session_id)
        after
          [stored_document: stored_document, session_state: session_state]
        end

      documents_in_state = result[:session_state].documents_by_id

      assert result[:stored_document] == any_entity
      assert Map.has_key?(documents_in_state, "custom_key") == true
    end

    test "If the entity is null, an error should be returned" do
      {:error, :null_entity} =
        OK.for do
          session_id <- Store.open_session("test")
          _ <- Session.store(session_id, nil)
        after
        end
    end

    test "If no valid id is found, an error should be returned" do
      any_entity = %{cat_name: Faker.Cat.name()}

      {:error, :no_valid_id_informed} =
        OK.for do
          session_id <- Store.open_session("test")
          _ <- Session.store(session_id, any_entity)
        after
        end
    end

    test "If an error happens while storing, returns it" do
      any_entity = %{id: UUID.uuid4(), cat_name: Faker.Cat.name()}

      {:error, :document_already_stored} =
        OK.for do
          session_id <- Store.open_session("test")
          _ <- Session.store(session_id, any_entity)

          new_clashing_entity = %{
            id: any_entity.id,
            cat_name: Faker.Cat.name()
          }

          _ <- Session.store(session_id, new_clashing_entity)
        after
        end
    end
  end

  describe "save_changes/1" do
    test "Documents on session should be saved" do
      any_entity = %{id: UUID.uuid4(), cat_name: Faker.Cat.name()}

      {:ok, save_result} =
        OK.for do
          session_id <- Store.open_session("test")
          _ <- Session.store(session_id, any_entity)
          result <- Session.save_changes(session_id)
        after
          result
        end

      assert save_result.status == 201
    end
  end
end
