defmodule Ravix.Documents.StoreTest do
  use ExUnit.Case

  import Ravix.Test.Random

  alias Ravix.Documents.Store

  setup do
    %{ravix: start_supervised!(Ravix)}
  end

  describe "A document store session" do
    test "should be opened succesfully" do
      {:ok, session_id} = Store.open_session("test")

      assert session_id != ""
    end
  end

  describe "Database administration operations" do
    test "A database should be created successfully" do
      random_db_seed = safe_random_string(5)

      {:ok, created_db} = Store.create_database(random_db_seed)

      assert created_db["Name"] == random_db_seed
    end

    test "If the database already exists, return an error" do
      random_db_seed = safe_random_string(5)

      {:ok, _} = Store.create_database(random_db_seed)
      {:error, error} = Store.create_database(random_db_seed)

      assert String.contains?(error, "already exists")
    end
  end
end
