defmodule Ravix.RQL.QueryTest do
  use ExUnit.Case
  require OK

  import Ravix.RQL.Query
  import Ravix.RQL.Tokens.Condition

  alias Ravix.Documents.{Store, Session}

  setup do
    %{ravix: start_supervised!(Ravix)}
  end

  describe "list_all/2" do
    test "Should list all the matching documents of a query" do
      any_entity = %{id: UUID.uuid4(), cat_name: Faker.Cat.name()}

      {:ok, response} =
        OK.for do
          session_id <- Store.open_session("test")
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
          session_id <- Store.open_session("test")
          query_response <-
            from("@all_docs")
            |> where(equal_to("cat_name", "Scrubbers, the destroyer"))
            |> list_all(session_id)
        after
          query_response
        end

      results = response["Results"]

      assert length(results) == 0
    end
  end
end
