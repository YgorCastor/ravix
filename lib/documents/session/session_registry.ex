defmodule Ravix.Documents.Session.Registry do
  @registry :sessions

  def session_name(name), do: {:via, Registry, {@registry, name}}
end
