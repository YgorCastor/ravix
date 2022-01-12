defmodule Ravix.Documents.Session do
  use GenServer

  require OK

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

  def fetch_state(session_id) do
    session_id
    |> session_id()
    |> GenServer.call({:fetch_state})
  end

  def load(session_id, id) do
    session_id
    |> session_id()
    |> GenServer.call({:load, id})
  end

  @spec store(binary(), any(), binary() | nil) :: {:ok, any()} | {:error, atom()}
  def store(session_id, entity, key \\ nil)

  def store(_session_id, entity, _key) when entity == nil, do: {:error, :null_entity}

  def store(session_id, entity, key) do
    session_id
    |> session_id()
    |> GenServer.call({:store, [entity | key]})
  end

  @spec session_id(String.t()) :: {:via, Registry, {:sessions, String.t()}}
  defp session_id(id), do: {:via, Registry, {:sessions, id}}

  defp save_entity(state = %Session.State{}, entity, key) do
    OK.try do
      updated_state <- Session.State.register_document(state, key, entity)
    after
      {:reply, {:ok, entity}, updated_state}
    rescue
      err -> {:reply, {:error, err}, state}
    end
  end

  ####################
  #     Handlers     #
  ####################
  def handle_call({:store, [entity | key]}, _from, state = %Session.State{}) when key != nil do
    save_entity(state, entity, key)
  end

  def handle_call({:store, [entity | _key]}, _from, state = %Session.State{})
      when entity.id != nil do
    save_entity(state, entity, entity.id)
  end

  def handle_call({:store, [_entity | _key]}, _from, state = %Session.State{}),
    do: {:reply, {:error, :no_valid_id_informed}, state}

  def handle_call({:fetch_state}, _from, state = %Session.State{}) do
    {:reply, {:ok, state}, state}
  end
end
