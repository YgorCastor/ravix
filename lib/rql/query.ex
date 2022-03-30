defmodule Ravix.RQL.Query do
  @moduledoc """
  Detructurized Raven Query Language structure
  """
  defstruct from_token: nil,
            where_token: nil,
            update_token: nil,
            and_tokens: [],
            or_tokens: [],
            projection_token: nil,
            limit_token: nil,
            query_string: "",
            query_params: %{},
            params_count: 0,
            aliases: %{},
            is_raw: false

  require OK

  alias Ravix.RQL.Query
  alias Ravix.RQL.QueryParser
  alias Ravix.RQL.Tokens.{Where, From, And, Or, Condition, Update, Limit}
  alias Ravix.Documents.Session

  @type t :: %Query{
          from_token: From.t() | nil,
          where_token: Where.t() | nil,
          update_token: Update.t() | nil,
          and_tokens: list(And.t()),
          or_tokens: list(Or.t()),
          projection_token: any(),
          limit_token: Limit.t() | nil,
          query_string: String.t(),
          query_params: map(),
          params_count: non_neg_integer(),
          aliases: map(),
          is_raw: boolean()
        }

  @doc """
  Adds a `Ravix.RQL.Tokens.From` to the query
  """
  @spec from(nil | bitstring) :: {:error, :query_document_must_be_informed} | Query.t()
  def from(nil), do: {:error, :query_document_must_be_informed}

  def from(document) do
    %Query{
      from_token: From.from(document)
    }
  end

  @doc """
  Adds a `Ravix.RQL.Tokens.From` to the query with an alias
  """
  def from(document, as_alias) do
    %Query{
      from_token: From.from(document),
      aliases: Map.put(%{}, document, as_alias)
    }
  end

  @doc """
  Adds a `Ravix.RQL.Tokens.Update` to the query
  """
  @spec update(Query.t(), map()) :: Query.t()
  def update(%Query{} = query, document_updates) do
    %Query{
      query
      | update_token: Update.update(document_updates)
    }
  end

  @doc """
  Adds a `Ravix.RQL.Tokens.Where` to the query
  """
  @spec where(Query.t(), Condition.t()) :: Query.t()
  def where(%Query{} = query, %Condition{} = condition) do
    %Query{
      query
      | where_token: Where.condition(condition)
    }
  end

  @doc """
  Adds a `Ravix.RQL.Tokens.And` to the query
  """
  @spec and?(Query.t(), Condition.t()) :: Query.t()
  def and?(%Query{} = query, %Condition{} = condition) do
    %Query{
      query
      | and_tokens: query.and_tokens ++ [And.condition(condition)]
    }
  end

  @doc """
  Adds a `Ravix.RQL.Tokens.Or` to the query
  """
  @spec or?(Query.t(), Condition.t()) :: Query.t()
  def or?(%Query{} = query, %Condition{} = condition) do
    %Query{
      query
      | or_tokens: query.or_tokens ++ [Or.condition(condition)]
    }
  end

  @spec limit(Query.t(), non_neg_integer, non_neg_integer) :: Query.t()
  def limit(%Query{} = query, skip, next) do
    %Query{
      query
      | limit_token: Limit.limit(skip, next)
    }
  end

  @doc """
  Create a Query using a raw RQL string
  """
  @spec raw(String.t()) :: Query.t()
  def raw(raw_query) do
    %Query{
      query_string: raw_query,
      is_raw: true
    }
  end

  @doc """
  Create a Query using a raw RQL string with parameters
  """
  @spec raw(String.t(), map()) :: Query.t()
  def raw(raw_query, params) do
    %Query{
      query_string: raw_query,
      query_params: params,
      is_raw: true
    }
  end

  @doc """
  Executes a list query in the informed session
  """
  @spec list_all(Query.t(), binary) :: {:error, any} | {:ok, any}
  def list_all(%Query{} = query, session_id) do
    execute_for(query, session_id, "POST")
  end

  @doc """
  Delete all the documents that matches the informed query
  """
  @spec delete_for(Query.t(), binary) :: {:error, any} | {:ok, any}
  def delete_for(%Query{} = query, session_id) do
    execute_for(query, session_id, "DELETE")
  end

  @doc """
  Updates all the documents that matches the informed query
  """
  @spec update_for(Query.t(), binary) :: {:error, any} | {:ok, any}
  def update_for(%Query{} = query, session_id) do
    execute_for(query, session_id, "PATCH")
  end

  defp execute_for(%Query{is_raw: false} = query, session_id, method) do
    case QueryParser.parse(query) do
      {:ok, parsed_query} -> Session.execute_query(parsed_query, session_id, method)
      {:error, err} -> {:error, err}
    end
  end

  defp execute_for(%Query{is_raw: true} = query, session_id, method) do
    Session.execute_query(query, session_id, method)
  end
end
