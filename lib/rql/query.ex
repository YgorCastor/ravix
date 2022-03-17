defmodule Ravix.RQL.Query do
  defstruct from_token: nil,
            where_token: nil,
            update_token: nil,
            and_tokens: [],
            or_tokens: [],
            projection_token: nil,
            query_string: "",
            query_params: %{},
            params_count: 0,
            aliases: %{},
            is_raw: false

  require OK

  alias Ravix.RQL.Query
  alias Ravix.RQL.QueryParser
  alias Ravix.RQL.Tokens.{Where, From, And, Or, Condition, Update}
  alias Ravix.Documents.Session
  alias Ravix.Connection.{RequestExecutor, RequestExecutorHelper}
  alias Ravix.Documents.Commands.ExecuteQueryCommand
  alias Ravix.Connection.InMemoryNetworkState
  alias Ravix.Documents.Store

  @type t :: %Query{
          from_token: From.t() | nil,
          where_token: Where.t() | nil,
          update_token: Update.t() | nil,
          and_tokens: list(And.t()),
          or_tokens: list(Or.t()),
          projection_token: any(),
          query_string: String.t(),
          query_params: map(),
          params_count: non_neg_integer(),
          aliases: map(),
          is_raw: boolean()
        }

  @spec from(nil | bitstring) :: {:error, :query_document_must_be_informed} | Query.t()
  def from(nil), do: {:error, :query_document_must_be_informed}

  def from(document) do
    %Query{
      from_token: From.from(document)
    }
  end

  def from(document, as_alias) do
    %Query{
      from_token: From.from(document),
      aliases: Map.put(%{}, document, as_alias)
    }
  end

  @spec update(Query.t(), map()) :: Query.t()
  def update(%Query{} = query, document_updates) do
    %Query{
      query
      | update_token: Update.update(document_updates)
    }
  end

  @spec where(Query.t(), Condition.t()) :: Query.t()
  def where(%Query{} = query, %Condition{} = condition) do
    %Query{
      query
      | where_token: Where.condition(condition)
    }
  end

  @spec and?(Query.t(), Condition.t()) :: Query.t()
  def and?(%Query{} = query, %Condition{} = condition) do
    %Query{
      query
      | and_tokens: query.and_tokens ++ [And.condition(condition)]
    }
  end

  @spec or?(Query.t(), Condition.t()) :: Query.t()
  def or?(%Query{} = query, %Condition{} = condition) do
    %Query{
      query
      | or_tokens: query.or_tokens ++ [Or.condition(condition)]
    }
  end

  @spec raw(String.t()) :: Query.t()
  def raw(raw_query) do
    %Query{
      query_string: raw_query,
      is_raw: true
    }
  end

  @spec raw(String.t(), map()) :: Query.t()
  def raw(raw_query, params) do
    %Query{
      query_string: raw_query,
      query_params: params,
      is_raw: true
    }
  end

  @spec list_all(Query.t(), binary) :: {:error, any} | {:ok, any}
  def list_all(%Query{} = query, session_id) do
    execute_for(query, session_id, "POST")
  end

  @spec delete_for(Query.t(), binary) :: {:error, any} | {:ok, any}
  def delete_for(%Query{} = query, session_id) do
    execute_for(query, session_id, "DELETE")
  end

  @spec update_for(Query.t(), binary) :: {:error, any} | {:ok, any}
  def update_for(%Query{} = query, session_id) do
    execute_for(query, session_id, "PATCH")
  end

  defp execute_for(%Query{is_raw: false} = query, session_id, method) do
    case QueryParser.parse(query) do
      {:ok, parsed_query} -> execute_query(parsed_query, session_id, method)
      {:error, err} -> {:error, err}
    end
  end

  defp execute_for(%Query{is_raw: true} = query, session_id, method) do
    execute_query(query, session_id, method)
  end

  defp execute_query(query, session_id, method) do
    OK.for do
      store_state = Store.fetch_configs()
      session_state <- Session.fetch_state(session_id)
      network_state <- InMemoryNetworkState.fetch_state(session_state.database)
      request_opts = RequestExecutorHelper.parse_retry_options(store_state)

      command = %ExecuteQueryCommand{
        Query: query.query_string,
        QueryParameters: query.query_params,
        method: method
      }

      result <- RequestExecutor.execute(command, network_state, {}, request_opts)
    after
      result.data
    end
  end
end
