defmodule Ravix.RQL.QueryTest do
  use ExUnit.Case, async: true
  require OK

  import Ravix.RQL.Query
  import Ravix.RQL.Tokens.Condition
  import Ravix.Factory

  alias Ravix.Documents.Session
  alias Ravix.TestStore, as: Store

  setup do
    %{ravix: start_supervised!(Ravix.TestApplication)}
    :ok
  end

  describe "list_all/2" do
    test "Should list all the matching documents of a query" do
      any_entity = %{id: UUID.uuid4(), cat_name: Faker.Cat.name()}

      {:ok, response} =
        OK.for do
          session_id <- Store.open_session()
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
          session_id <- Store.open_session()

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

    test "Should be able to run with a raw query" do
      any_entity = %{id: UUID.uuid4(), cat_name: Faker.Cat.name()}

      {:ok, response} =
        OK.for do
          session_id <- Store.open_session()
          _ <- Session.store(session_id, any_entity)
          _ <- Session.save_changes(session_id)

          :timer.sleep(500)

          query_response <-
            raw("from @all_docs where cat_name = \"#{any_entity.cat_name}\"")
            |> list_all(session_id)
        after
          query_response
        end

      results = response["Results"]
      saved_cat = Enum.find(results, nil, fn entity -> entity["id"] == any_entity.id end)

      assert saved_cat["id"] == any_entity.id
      assert saved_cat["cat_name"] == any_entity.cat_name
    end

    test "Should be able to run with a parametrized raw query" do
      any_entity = %{id: UUID.uuid4(), cat_name: Faker.Cat.name()}

      {:ok, response} =
        OK.for do
          session_id <- Store.open_session()
          _ <- Session.store(session_id, any_entity)
          _ <- Session.save_changes(session_id)

          :timer.sleep(500)

          query_response <-
            raw("from @all_docs where cat_name = $p1", %{p1: any_entity.cat_name})
            |> list_all(session_id)
        after
          query_response
        end

      results = response["Results"]
      saved_cat = Enum.find(results, nil, fn entity -> entity["id"] == any_entity.id end)

      assert saved_cat["id"] == any_entity.id
      assert saved_cat["cat_name"] == any_entity.cat_name
    end

    test "A invalid query should return an error" do
      {:error, "1:1 Expected FROM clause but got: never\nQuery: \nnever gonna give you up"} =
        OK.for do
          session_id <- Store.open_session()

          query_response <-
            raw("never gonna give you up")
            |> list_all(session_id)
        after
          query_response
        end
    end

    test "Should return only the selected field" do
      cat = build(:cat_entity)

      {:ok, response} =
        OK.for do
          session_id <- Store.open_session()
          _ <- Session.store(session_id, cat)
          _ <- Session.save_changes(session_id)

          :timer.sleep(500)

          query_response <-
            from("Cats")
            |> select("name")
            |> where(equal_to("name", cat.name))
            |> list_all(session_id)
        after
          query_response
        end

      found_cat =
        Enum.find(response["Results"], nil, fn entity -> entity["@metadata"]["@id"] == cat.id end)

      assert found_cat["name"] == cat.name
      refute Map.has_key?(found_cat, "breed")
    end

    test "Should return only the selected fields" do
      cat = build(:cat_entity)

      {:ok, response} =
        OK.for do
          session_id <- Store.open_session()
          _ <- Session.store(session_id, cat)
          _ <- Session.save_changes(session_id)

          :timer.sleep(500)

          query_response <-
            from("Cats")
            |> select(["name", "breed"])
            |> where(equal_to("name", cat.name))
            |> list_all(session_id)
        after
          query_response
        end

      found_cat =
        Enum.find(response["Results"], nil, fn entity -> entity["@metadata"]["@id"] == cat.id end)

      assert found_cat["name"] == cat.name
      assert found_cat["breed"] == cat.breed
      refute Map.has_key?(found_cat, "id")
    end

    test "Should limit the responses if the limit function was applied" do
      glaring = build_list(5, :cat_entity)

      {:ok, response} =
        OK.for do
          session_id <- Store.open_session()

          _ =
            glaring
            |> Enum.map(fn cat ->
              Session.store(session_id, cat)
            end)

          _ <- Session.save_changes(session_id)

          :timer.sleep(500)

          query_response <-
            from("Cats")
            |> limit(1, 2)
            |> list_all(session_id)
        after
          query_response
        end

      assert [_, _] = response["Results"]
    end

    test "Should not return rows referenced in a 'not in' operation" do
      el_cato = build(:cat_entity)

      {:ok, response} =
        OK.for do
          session_id <- Store.open_session()
          _ <- Session.store(session_id, el_cato)
          _ <- Session.save_changes(session_id)

          :timer.sleep(500)

          query_response <-
            from("Cats")
            |> where(not_in("id", [el_cato.id]))
            |> list_all(session_id)
        after
          query_response
        end

      refute response["Results"] |> Enum.any?(fn cato -> cato["id"] == el_cato.id end)
    end

    test "The 'Not' operation works correctly with a binary op" do
      [cat1, cat2, cat3] = build_list(3, :cat_entity)

      {:ok, response} =
        OK.for do
          session_id <- Store.open_session()
          _ <- Session.store(session_id, cat1)
          _ <- Session.store(session_id, cat2)
          _ <- Session.store(session_id, cat3)
          _ <- Session.save_changes(session_id)

          :timer.sleep(500)

          query_response <-
            from("Cats")
            |> where(not_equal_to("id", cat1.id))
            |> and_not(equal_to("id", cat2.id))
            |> or?(equal_to("id", cat3.id))
            |> list_all(session_id)
        after
          query_response
        end

      assert response["Results"] |> Enum.any?(fn cat -> cat["id"] == cat3.id end)
    end
  end

  describe "delete_for/2" do
    test "Should delete documents that match the query" do
      any_entity = %{id: UUID.uuid4(), cat_name: Faker.Cat.name()}
      any_entity_2 = %{id: UUID.uuid4(), cat_name: Faker.Cat.name()}

      {:ok, [delete_response, query_response]} =
        OK.for do
          session_id <- Store.open_session()
          _ <- Session.store(session_id, any_entity)
          _ <- Session.store(session_id, any_entity_2)
          _ <- Session.save_changes(session_id)

          :timer.sleep(500)

          delete_response <-
            from("@all_docs")
            |> where(equal_to("cat_name", any_entity.cat_name))
            |> delete_for(session_id)

          :timer.sleep(500)

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
          session_id <- Store.open_session()
          _ <- Session.store(session_id, any_entity)
          _ <- Session.store(session_id, any_entity_2)
          _ <- Session.save_changes(session_id)

          :timer.sleep(500)

          update_response <-
            from("@all_docs", "a")
            |> update(%{cat_name: "Fluffer, the hand-ripper"})
            |> where(equal_to("cat_name", any_entity.cat_name))
            |> update_for(session_id)

          :timer.sleep(500)

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
