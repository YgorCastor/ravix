defmodule Ravix.Documents.Session do
  use GenServer

  import Ravix.Documents.Session.Registry

  alias Ravix.Documents.Session.State

  def init(session_state) do
    {:ok, session_state}
  end

  @spec start_link(any, Ravix.Documents.Session.State.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(_attr, initial_state = %State{}) do
    GenServer.start_link(__MODULE__, initial_state, name: session_name(initial_state.session_id))
  end

  def load(session_id, id) do
    session_id
    |> session_name()
    |> GenServer.call(:load, id)
  end

  ####################
  #     Handlers     #
  ####################

  def handle_call(:load, _id, %State{} = state) do
    {:reply, :ok, state}
  end
end
