defmodule Ravix.Test.Cache do
  @moduledoc false
  use Nebulex.Cache,
    otp_app: :ravix,
    adapter: Nebulex.Adapters.Local
end
