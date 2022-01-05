defmodule Ravix.Documents.StoreTest do
  use ExUnit.Case

  alias Ravix.Documents.Store

  setup do
    %{ravix: start_supervised!(Ravix)}
  end

  describe "A document store session" do
    test "should be opened succesfully" do
      {:ok, session_id} = Store.open_session("test", "3c2e4d5d-aeeb-464c-ba4f-bd94d1aede1c")

      assert session_id != ""
    end
  end
end
