defmodule Ravix.Documents.Store do
  @moduledoc """
  Macro to define a RavenDB Repository Store

  ## Example

      `defmodule Ravix.TestRepo do
         use Ravix.Documents.Store
       end`
  """

  defmacro __using__(opts) do
    require OK

    quote bind_quoted: [opts: opts] do
      @behaviour Ravix.Documents.Store

      otp_app = Ravix.Connection.Supervisor.compile_config(opts)

      @otp_app otp_app

      def start_link(opts \\ []) do
        Ravix.Connection.Supervisor.start_link(__MODULE__, @otp_app, opts)
      end

      def open_session() do
        session_id = UUID.uuid4()
        {:ok, conn_state} = Ravix.Connection.fetch_state(__MODULE__)

        session_initial_state = %Ravix.Documents.Session.State{
          store: __MODULE__,
          session_id: session_id,
          database: conn_state.database,
          conventions: conn_state.conventions
        }

        {:ok, _} = Ravix.Documents.Session.Supervisor.create_session(session_initial_state)

        {:ok, session_id}
      end

      def close_session(session_id) do
        Ravix.Documents.Session.Supervisor.close_session(__MODULE__, session_id)
      end

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end
    end
  end

  @callback start_link(opts :: Keyword.t()) ::
              {:ok, pid}
              | {:error, {:already_started, pid}}
              | {:error, term}

  @doc """
  Opens a RavenDB local session

  Returns a tuple with `{:ok, uuid}` if successful or `{:error, :not_found}` if the store
  is not initialized

  ## Examples
      iex> Ravix.Test.Store.open_session
      {:ok, "8945c215-dd67-44da-9a64-2916e0a328d9"}
  """
  @callback open_session() :: {:ok, binary()}

  @doc """
  Closes a RavenDB local session

  Returns `:ok` if successful or `{:error, :not_found}` if the session
  is not found

  ## Examples
      iex> Ravix.Test.Store.close_session("8945c215-dd67-44da-9a64-2916e0a328d9")
      :ok
  """
  @callback close_session(session_id :: binary()) :: :ok | {:error, :not_found}
end
