defmodule Ravix.Documents.Session.SessionsSupervisor do
  use DynamicSupervisor

  alias Ravix.Documents.Session.State
  alias Ravix.Documents.Session

  def init(init_arg) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: [init_arg]
    )
  end

  def start_link(attrs) do
    DynamicSupervisor.start_link(__MODULE__, attrs, name: __MODULE__)
  end

  @spec create_session(State.t()) :: :ignore | {:error, any} | {:ok, pid} | {:ok, pid, any}
  def create_session(%State{} = session_state) do
    DynamicSupervisor.start_child(__MODULE__, {Session, session_state})
  end
end
