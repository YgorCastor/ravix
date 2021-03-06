defmodule Ravix.Documents.Session.Supervisor do
  @moduledoc """
  Supervisor for RavenDB Sessions
  """
  use DynamicSupervisor

  alias Ravix.Documents.Session
  alias Ravix.Documents.Session.State, as: SessionState

  def init(init_arg) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: [init_arg]
    )
  end

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(store) do
    DynamicSupervisor.start_link(__MODULE__, %{}, name: supervisor_name(store))
  end

  @doc """
  Creates a session with the informed initial state
  """
  @spec create_session(SessionState.t()) :: :ignore | {:error, any} | {:ok, pid} | {:ok, pid, any}
  def create_session(%SessionState{} = session_state) do
    session_state = session_state |> SessionState.update_last_session_call()
    DynamicSupervisor.start_child(supervisor_name(session_state.store), {Session, session_state})
  end

  @doc """
  Closes a session for the informed store using the session pid or session_id
  """
  @spec close_session(atom(), pid | bitstring()) :: :ok | {:error, :not_found}
  def close_session(store, pid) when is_pid(pid) do
    DynamicSupervisor.terminate_child(supervisor_name(store), pid)
  end

  def close_session(store, session_id) do
    case Registry.lookup(:sessions, session_id) do
      [] ->
        {:error, :not_found}

      sessions ->
        {pid, _} = sessions |> Enum.at(0)
        DynamicSupervisor.terminate_child(supervisor_name(store), pid)
    end
  end

  defp supervisor_name(store) do
    :"#{store}.Sessions"
  end
end
