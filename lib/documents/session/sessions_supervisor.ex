defmodule Ravix.Documents.Session.Supervisor do
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

  def create_supervised_session(session_state = %State{}) do
    DynamicSupervisor.start_child(__MODULE__, {Session, session_state})
  end
end
