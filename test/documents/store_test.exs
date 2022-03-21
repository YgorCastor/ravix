defmodule Ravix.Documents.StoreTest do
  use ExUnit.Case

  import Ravix.Test.Random

  alias Ravix.TestStore, as: Store

  setup do
    %{ravix: start_supervised!(Ravix)}
  end
end
