defmodule Ravix.Documents.Session do
  @moduledoc """
  A stateful session to execute ravendb commands
  """
  use GenServer

  require OK
  require Logger

  alias Ravix.Documents.Session.State, as: SessionState
  alias Ravix.Documents.Session.Manager, as: SessionManager
  alias Ravix.Documents.Session.Supervisor, as: SessionSupervisor

  def init(session_state) do
    {:ok, session_state, {:continue, :session_ttl_checker}}
  end

  @spec start_link(any, SessionState.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(_attr, %SessionState{} = initial_state) do
    GenServer.start_link(
      __MODULE__,
      initial_state,
      name: session_id(initial_state.session_id)
    )
  end

  @doc """
  Loads the document from the database to the local session

  ## Parameters
  - session_id: the session_id
  - ids: the document ids to be loaded
  - includes: the document includes path
  - opts: load options

  ## Returns
  - `{:ok, results}`
  - `{:errors, cause}`
  """
  @spec load(binary(), list() | bitstring(), any, keyword() | nil) :: any
  def load(session_id, ids, includes \\ nil, opts \\ nil)
  def load(_session_id, nil, _includes, _opts), do: {:error, :document_ids_not_informed}

  def load(session_id, ids, includes, opts) when is_list(ids) do
    session_id
    |> session_id()
    |> GenServer.call({:load, [document_ids: ids, includes: includes, opts: opts]})
  end

  def load(session_id, id, includes, opts) do
    session_id
    |> session_id()
    |> GenServer.call({:load, [document_ids: [id], includes: includes, opts: opts]})
  end

  @doc """
  Marks the document for deletion

  ## Parameters
  - session_id: the session id
  - entity: the document to be deleted

  ## Returns
  - `{:ok, updated_state}`
  - `{:error, cause}`
  """
  @spec delete(binary, map()) :: any
  def delete(session_id, entity) when is_map_key(entity, :id) do
    delete(session_id, entity.id)
  end

  def delete(session_id, id) when is_binary(id) do
    session_id
    |> session_id()
    |> GenServer.call({:delete, id})
  end

  @doc """
  Add a document to the session to be created

  ## Parameters
  - session_id: the session id
  - entity: the document to store
  - key: the document key to be used
  - change_vector: the concurrency change vector

  ## Returns
  - `{:ok, updated_session}`
  - `{:error, cause}`
  """
  @spec store(binary(), map(), binary() | nil, binary() | nil) :: any
  def store(session_id, entity, key \\ nil, change_vector \\ nil)

  def store(_session_id, entity, _key, _change_vector) when entity == nil,
    do: {:error, :null_entity}

  def store(session_id, entity, key, change_vector) do
    session_id
    |> session_id()
    |> GenServer.call({:store, [entity: entity, key: key, change_vector: change_vector]})
  end

  @doc """
  Persists the session changes to the RavenDB database
  """
  @spec save_changes(binary) :: any
  def save_changes(session_id) do
    session_id
    |> session_id()
    |> GenServer.call({:save_changes})
  end

  @doc """
  Fetches the current session state
  """
  @spec fetch_state(binary()) :: {:error, :session_not_found} | {:ok, SessionState.t()}
  def fetch_state(session_id) do
    try do
      {:ok,
       session_id
       |> session_id()
       |> :sys.get_state()}
    catch
      :exit, _ -> {:error, :session_not_found}
    end
  end

  @doc """
  Executes a query into the RavenDB

  ## Paremeters
  - query: The `Ravix.RQL.Query` to be executed
  - session_id: the session_id
  - method: The http method
  """
  @spec execute_query(any, binary, any) :: any
  def execute_query(query, session_id, method) do
    session_id
    |> session_id()
    |> GenServer.call({:execute_query, query, method})
  end

  @spec session_id(String.t()) :: {:via, Registry, {:sessions, String.t()}}
  defp session_id(id) when id != nil, do: {:via, Registry, {:sessions, id}}

  ####################
  #     Handlers     #
  ####################
  def handle_call(
        {:load, [document_ids: ids, includes: includes, opts: opts]},
        _from,
        %SessionState{} = state
      ) do
    case SessionManager.load_documents(state, ids, includes, opts) do
      {:ok, result} -> {:reply, {:ok, result[:response]}, result[:updated_state]}
      err -> {:reply, err, state}
    end
  end

  def handle_call(
        {:store, [entity: entity, key: key, change_vector: change_vector]},
        _from,
        %SessionState{} = state
      )
      when key != nil do
    OK.try do
      [entity, updated_state] <- SessionManager.store_entity(state, entity, key, change_vector)
    after
      {:reply, {:ok, entity}, updated_state}
    rescue
      err -> {:reply, {:error, err}, state}
    end
  end

  def handle_call(
        {:store, [entity: entity, key: _, change_vector: change_vector]},
        _from,
        %SessionState{} = state
      )
      when entity.id != nil do
    OK.try do
      [entity, updated_state] <-
        SessionManager.store_entity(state, entity, entity.id, change_vector)
    after
      {:reply, {:ok, entity}, updated_state}
    rescue
      err -> {:reply, {:error, err}, state}
    end
  end

  def handle_call(
        {:store, [entity: _, key: _, change_vector: _]},
        _from,
        %SessionState{} = state
      ),
      do: {:reply, {:error, :no_valid_id_informed}, state}

  def handle_call({:save_changes}, _from, %SessionState{} = state) do
    case SessionManager.save_changes(state) do
      {:ok, response} -> {:reply, {:ok, response[:result]}, response[:updated_state]}
      {:error, err} -> {:reply, {:error, err}, state}
    end
  end

  def handle_call({:delete, id}, _from, %SessionState{} = state) do
    case SessionManager.delete_document(state, id) do
      {:ok, updated_state} -> {:reply, {:ok, id}, updated_state}
      {:error, err} -> {:reply, {:error, err}, state}
    end
  end

  def handle_call({:execute_query, query, method}, from, %SessionState{} = state) do
    reference = make_ref()
    self_pid = self()

    Task.start(fn ->
      response = SessionManager.execute_query(state, query, method)
      GenServer.cast(self_pid, {:query_processed, reference, response})
    end)

    {:noreply,
     %SessionState{state | running_queries: Map.put(state.running_queries, reference, from)}
     |> SessionState.update_last_session_call()}
  end

  def handle_cast({:query_processed, reference, response}, %SessionState{} = state) do
    {from, remaining_queries} = Map.pop(state.running_queries, reference)

    GenServer.reply(from, response)

    {:noreply,
     %SessionState{state | running_queries: remaining_queries}
     |> SessionState.update_last_session_call()}
  end

  def handle_info(:check_session, %SessionState{} = state) do
    self_pid = self()

    Task.start(fn ->
      if Timex.diff(Timex.now(), state.last_session_call, :seconds) >
           state.conventions.session_idle_ttl do
        Logger.warn(
          "[RAVIX] The session #{state.session_id} timed-out because it was inactive for more than #{inspect(state.conventions.session_idle_ttl)} seconds"
        )

        SessionSupervisor.close_session(state.store, self_pid)
      end
    end)

    {:noreply, state}
  end

  def handle_continue(:session_ttl_checker, %SessionState{} = state) do
    Process.send_after(self(), :check_session, 5000)

    {:noreply, state}
  end
end
