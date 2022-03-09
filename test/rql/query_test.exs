defmodule Ravix.RQL.QueryTest do
  use ExUnit.Case
  require OK

  import Ravix.RQL.Query
  import Ravix.RQL.Tokens.Condition

  alias Ravix.Documents.{Store, Session}

  setup do
    ravix = %{ravix: start_supervised!(Ravix)}
    Store.create_database("test")
    ravix
  end

  describe "list_all/2" do
    test "Should list all the matching documents of a query" do
      any_entity = %{id: UUID.uuid4(), cat_name: Faker.Cat.name()}

      {:ok, response} =
        OK.for do
          session_id <- Store.open_session("test")
          _ <- Session.store(session_id, any_entity)
          _ <- Session.save_changes(session_id)
          :timer.sleep(500)

          query_response <-
            from("@all_docs")
            |> where(equal_to("cat_name", any_entity.cat_name))
            |> list_all(session_id)
        after
          query_response
        end

      results = response["Results"]
      saved_cat = Enum.find(results, nil, fn entity -> entity["id"] == any_entity.id end)

      assert saved_cat["id"] == any_entity.id
      assert saved_cat["cat_name"] == any_entity.cat_name
    end

    test "If no results, it should be a valid response with empty results" do
      {:ok, response} =
        OK.for do
          session_id <- Store.open_session("test")

          query_response <-
            from("@all_docs")
            |> where(equal_to("cat_name", "Scrubbers, the destroyer"))
            |> list_all(session_id)
        after
          query_response
        end

      results = response["Results"]

      assert results == []
    end
  end

  describe "delete_for/2" do
    test "Should delete documents that match the query" do
      any_entity = %{id: UUID.uuid4(), cat_name: Faker.Cat.name()}
      any_entity_2 = %{id: UUID.uuid4(), cat_name: Faker.Cat.name()}

      {:ok, [delete_response, query_response]} =
        OK.for do
          session_id <- Store.open_session("test")
          _ <- Session.store(session_id, any_entity)
          _ <- Session.store(session_id, any_entity_2)
          _ <- Session.save_changes(session_id)

          :timer.sleep(1000)

          delete_response <-
            from("@all_docs")
            |> where(equal_to("cat_name", any_entity.cat_name))
            |> delete_for(session_id)

          :timer.sleep(1000)

          query_response <-
            from("@all_docs")
            |> where(equal_to("id", any_entity.id))
            |> or?(equal_to("id", any_entity_2.id))
            |> list_all(session_id)
        after
          [delete_response, query_response]
        end

      assert delete_response["OperationId"] != nil
      assert length(query_response["Results"]) == 1
    end
  end

  describe "update_for/2" do
    test "Should update documents that match the query" do
      any_entity = %{id: UUID.uuid4(), cat_name: Faker.Cat.name()}
      any_entity_2 = %{id: UUID.uuid4(), cat_name: Faker.Cat.name()}

      {:ok, [update_response, query_response]} =
        OK.for do
          session_id <- Store.open_session("test")
          _ <- Session.store(session_id, any_entity)
          _ <- Session.store(session_id, any_entity_2)
          _ <- Session.save_changes(session_id)

          :timer.sleep(1000)

          update_response <-
            from("@all_docs", "a")
            |> update(%{cat_name: "Fluffer, the hand-ripper"})
            |> where(equal_to("cat_name", any_entity.cat_name))
            |> update_for(session_id)

          :timer.sleep(1000)

          query_response <-
            from("@all_docs")
            |> where(equal_to("id", any_entity.id))
            |> or?(equal_to("id", any_entity_2.id))
            |> list_all(session_id)
        after
          [update_response, query_response]
        end

      results = query_response["Results"]
      updated_cat = Enum.find(results, nil, fn entity -> entity["id"] == any_entity.id end)

      assert update_response["OperationId"] != nil

      assert updated_cat["id"] == any_entity.id
      assert updated_cat["cat_name"] == "Fluffer, the hand-ripper"
    end
  end
end
