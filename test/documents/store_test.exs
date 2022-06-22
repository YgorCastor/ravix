defmodule Ravix.Documents.StoreTest do
  use Ravix.Integration.Case

  alias Ravix.Test.Store, as: Store

  describe "open_session/0" do
    test "Should open a session successfully" do
      {:ok, session_id} = Store.open_session()

      assert session_id != ""
    end
  end

  describe "close_session/0" do
    test "Should close a session successfully" do
      {:ok, session_id} = Store.open_session()

      :ok = Store.close_session(session_id)
    end

    test "If there's not a session, should return a :not_found error" do
      {:error, :not_found} = Store.close_session(UUID.uuid4())
    end
  end
end
