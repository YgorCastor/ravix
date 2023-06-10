defmodule Ravix.Test.Cache do
  use Nebulex.Cache,
    otp_app: :ravix,
    adapter: Nebulex.Adapters.Local
end
