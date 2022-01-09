defmodule Ravix.Documents.Session do
  use GenServer

  alias Ravix.Documents.Session

  def init(session_state) do
    {:ok, session_state}
  end

  @spec start_link(any, Session.State.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(_attr, initial_state = %Session.State{}) do
    GenServer.start_link(
      __MODULE__,
      initial_state,
      name: session_id(initial_state.session_id)
    )
  end

  def load(session_id, id) do
    session_id
    |> session_id()
    |> GenServer.call(:load, id)
  end

  @spec session_id(String.t()) :: {:via, Registry, {:sessions, String.t()}}
  defp session_id(id), do: {:via, Registry, {:sessions, id}}

  ####################
  #     Handlers     #
  ####################

  def handle_call(:load, _id, %Session.State{} = state) do
    {:reply, :ok, state}
  end
end
