defmodule Ravix.Documents.StoreTest do
  use ExUnit.Case

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
end
