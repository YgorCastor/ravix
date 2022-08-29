defmodule Ravix.RQL.QueryTest do
  use Ravix.Integration.Case
  require OK

  import Ravix.RQL.Query
  import Ravix.RQL.Tokens.Condition
  import Ravix.RQL.Tokens.Update
  import Ravix.Factory

  alias Ravix.RQL.Tokens.Order

  alias Ravix.Documents.Session
  alias Ravix.Test.Store, as: Store
  alias Ravix.Test.NonRetryableStore

  describe "list_all/2" do
    test "Should list all the matching documents of a query" do
      any_entity = %{id: UUID.uuid4(), cat_name: Faker.Cat.name()}

      {:ok, response} =
        OK.for do
          session_id <- Store.open_session()
          _ <- Session.store(session_id, any_entity)
          _ <- Session.save_changes(session_id)

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

    test "A invalid query should not kill the session" do
      any_entity = %{id: UUID.uuid4(), cat_name: Faker.Cat.name()}

      {:ok, _} =
        OK.for do
          session_id <- Store.open_session()

          _ =
            raw("never gonna give you up")
            |> list_all(session_id)

          _ <- Session.store(session_id, any_entity)
          _ <- Session.save_changes(session_id)

          query_response <-
            raw("from @all_docs where cat_name = \"#{any_entity.cat_name}\"")
            |> list_all(session_id)
        after
          query_response
        end
    end

    test "A invalid query should return an error" do
      {:error, "1:1 Expected FROM clause but got: never\nQuery: \nnever gonna give you up"} =
        OK.for do
          session_id <- Store.open_session()

          _ <-
            raw("never gonna give you up")
            |> list_all(session_id)
        after
        end
    end

    @tag :flaky
    test "If the query is stale, should return an error" do
      cat = build(:cat_entity)

      {:error, :stale} =
        OK.for do
          session_id <- NonRetryableStore.open_session()
          _ <- Session.store(session_id, cat)
          _ <- Session.save_changes(session_id)

          _ <-
            from("Cats")
            |> select("name")
            |> where(equal_to("name", cat.name))
            |> list_all(session_id)

          # The first query usually creates an auto_index, who gives time to the query to finish
          # If we query again, it will be faster, leading to a stale call
          query_response <-
            from("Cats")
            |> select("name")
            |> where(equal_to("name", cat.name))
            |> list_all(session_id)
        after
          query_response
        end
    end

    test "If the query is stale, but the retry_on_stale is on, it should return ok" do
      cat = build(:cat_entity)

      {:ok, _} =
        OK.for do
          session_id <- Store.open_session()
          _ <- Session.store(session_id, cat)
          _ <- Session.save_changes(session_id)

          query_response <-
            from("Cats")
            |> select("name")
            |> where(equal_to("name", cat.name))
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

    test "Should return only the selected field with the correct alias" do
      cat = build(:cat_entity)

      {:ok, response} =
        OK.for do
          session_id <- Store.open_session()
          _ <- Session.store(session_id, cat)
          _ <- Session.save_changes(session_id)

          query_response <-
            from("Cats")
            |> select({"name", "cat_name"})
            |> where(equal_to("name", cat.name))
            |> list_all(session_id)
        after
          query_response
        end

      found_cat =
        Enum.find(response["Results"], nil, fn entity -> entity["@metadata"]["@id"] == cat.id end)

      assert found_cat["cat_name"] == cat.name
    end

    test "Should order based on a single field" do
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
            |> where(in?("name", [cat1.name, cat2.name, cat3.name]))
            |> order_by(%Order.Field{name: "name", order: :asc})
            |> limit(0, 1)
            |> list_all(session_id)
        after
          query_response
        end

      found_cat = Enum.at(response["Results"], 0)

      sorted_cat =
        [cat1, cat2, cat3]
        |> Enum.sort_by(fn cat -> String.first(cat.name) end)
        |> Enum.at(0)

      :timer.sleep(200)

      assert found_cat["name"] == sorted_cat.name
      assert found_cat["breed"] == sorted_cat.breed
    end

    test "Should order based on multiple fields" do
      [cat1, cat2, cat3] = build_list(3, :cat_entity)

      {:ok, response} =
        OK.for do
          session_id <- Store.open_session()
          _ <- Session.store(session_id, cat1)
          _ <- Session.store(session_id, cat2)
          _ <- Session.store(session_id, cat3)
          _ <- Session.save_changes(session_id)

          query_response <-
            from("Cats")
            |> where(in?("name", [cat1.name, cat2.name, cat3.name]))
            |> order_by([
              %Order.Field{name: "@metadata.@last-modified", order: :desc, type: :number},
              %Order.Field{name: "name", order: :asc}
            ])
            |> limit(1, 2)
            |> list_all(session_id)
        after
          query_response
        end

      assert [_, _] = response["Results"]
    end

    test "Should support function select" do
      cat = build(:cat_entity)

      {:ok, response} =
        OK.for do
          session_id <- Store.open_session()
          _ <- Session.store(session_id, cat)
          _ <- Session.save_changes(session_id)

          query_response <-
            from("Cats", "c")
            |> where(equal_to("id", cat.id))
            |> select_function(ooga: "c.name")
            |> list_all(session_id)
        after
          query_response
        end

      assert [found_cat] = response["Results"]
      assert found_cat["ooga"] == cat.name
    end

    test "Should support group by" do
      cat = build(:cat_entity)

      {:ok, response} =
        OK.for do
          session_id <- Store.open_session()
          _ <- Session.store(session_id, cat)
          _ <- Session.save_changes(session_id)

          query_response <-
            from("Cats")
            |> group_by(["breed", "registry"])
            |> where(equal_to("breed", cat.breed))
            |> list_all(session_id)
        after
          query_response
        end

      il_cato =
        response["Results"] |> Enum.find(fn response -> response["breed"] == cat.breed end)

      assert il_cato["breed"] == cat.breed
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
            |> update(set(:cat_name, "Fluffer, the hand-ripper"))
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

  @tag :not_supported
  describe "stream_query/2" do
    test "should stream a query in a non-blocking way" do
      glaring = build_list(1000, :cat_entity)

      {:ok, stream} =
        OK.for do
          batches = Enum.chunk_every(glaring, 30)

          _ =
            batches
            |> Enum.each(fn batch ->
              {:ok, session_id} = Store.open_session()

              batch
              |> Enum.map(fn cat ->
                Session.store(session_id, cat)
              end)

              _ = Session.save_changes(session_id)
              _ = Store.close_session(session_id)
            end)

          session_id <- Store.open_session()

          stream <-
            from("Cats")
            |> stream_all(session_id)
        after
          stream
        end

      result = Enum.to_list(stream)

      assert 1000 = length(result)
    end
  end
end
