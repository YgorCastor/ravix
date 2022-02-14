defmodule Ravix.RQL.Query do
  defstruct from_token: nil,
            where_token: nil,
            and_tokens: [],
            or_tokens: [],
            projection_token: nil,
            query_string: "",
            query_params: %{},
            params_count: 0,
            is_raw: false

  require OK

  alias Ravix.RQL.Query
  alias Ravix.RQL.QueryParser
  alias Ravix.RQL.Tokens.{Where, From, And, Or, Condition}
  alias Ravix.Documents.Session
  alias Ravix.Connection.RequestExecutor
  alias Ravix.Documents.Commands.ExecuteQueryCommand
  alias Ravix.Connection.NetworkStateManager
  alias Ravix.Connection.Network.State, as: NetworkState

  def from(nil), do: {:error, :query_document_must_be_informed}

  def from(document, as_alias \\ nil) when is_bitstring(document) do
    %Query{
      from_token: From.from(document, as_alias)
    }
  end

  def where(%Query{} = query, %Condition{} = condition) do
    %Query{
      query
      | where_token: Where.condition(condition)
    }
  end

  def and?(%Query{} = query, %Condition{} = condition) do
    %Query{
      query
      | and_tokens: query.and_tokens ++ [And.condition(condition)]
    }
  end

  def or?(%Query{} = query, %Condition{} = condition) do
    %Query{
      query
      | or_tokens: query.or_tokens ++ [Or.condition(condition)]
    }
  end

  def raw(raw_query) do
    %Query{
      query_string: raw_query,
      is_raw: true
    }
  end

  def list_all(%Query{} = query, session_id) do
    execute_for(query, session_id, "POST")
  end

  def delete_for(%Query{} = query, session_id) do
    execute_for(query, session_id, "DELETE")
  end

  defp execute_for(%Query{is_raw: false} = query, session_id, method) do
    OK.for do
      parsed_query = QueryParser.parse(query)
      session_state = Session.fetch_state(session_id)
      {pid, _} <- NetworkStateManager.find_existing_network(session_state.database)
      network_state = Agent.get(pid, fn ns -> ns end)

      command = %ExecuteQueryCommand{
        Query: parsed_query.query_string,
        QueryParameters: parsed_query.query_params,
        method: method
      }

      result <- execute_query(command, network_state)
    after
      result
    end
  end

  defp execute_for(%Query{is_raw: true} = query, session_id, method) do
    OK.for do
      session_state = Session.fetch_state(session_id)
      {pid, _} <- NetworkStateManager.find_existing_network(session_state.database)
      network_state = Agent.get(pid, fn ns -> ns end)

      command = %ExecuteQueryCommand{
        Query: query.query_string,
        method: method
      }

      result <- execute_query(command, network_state)
    after
      result
    end
  end

  defp execute_query(%ExecuteQueryCommand{} = command, %NetworkState{} = state) do
    OK.for do
      response <- RequestExecutor.execute(command, state)
      result <- Jason.decode(response.data)
    after
      result
    end
  end
end
