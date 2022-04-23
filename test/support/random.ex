defmodule Ravix.Test.Random do
  @moduledoc false
  def safe_random_string(size) do
    :crypto.strong_rand_bytes(size) |> Base.url_encode64() |> binary_part(0, size)
  end
end
