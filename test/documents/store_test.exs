defmodule Ravix.Documents.StoreTest do
  use ExUnit.Case

  alias Ravix.TestStore, as: Store

  setup do
    %{ravix: start_supervised!(Ravix.TestApplication)}
    :ok
  end

  describe "open_session/0" do
    test "Should open a session successfully" do
      {:ok, session_id} = Store.open_session()

      assert session_id != ""
    end
  end
end
