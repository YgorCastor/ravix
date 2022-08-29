defmodule Ravix.RQL.Query do
  @moduledoc """
  Detructurized Raven Query Language structure
  """
  defstruct from_token: nil,
            where_token: nil,
            update_token: nil,
            and_tokens: [],
            or_tokens: [],
            group_token: nil,
            select_token: nil,
            order_token: nil,
            limit_token: nil,
            query_string: "",
            query_params: %{},
            params_count: 0,
            aliases: %{},
            is_raw: false

  require OK

  alias Ravix.RQL.Query
  alias Ravix.RQL.QueryParser

  alias Ravix.RQL.Tokens.{
    Where,
    Select,
    From,
    And,
    Or,
    Condition,
    Update,
    Limit,
    Not,
    Order,
    Group
  }

  alias Ravix.Documents.Session

  @type t :: %Query{
          from_token: From.t() | nil,
          where_token: Where.t() | nil,
          update_token: Update.t() | nil,
          and_tokens: list(And.t()),
          or_tokens: list(Or.t()),
          group_token: Group.t() | nil,
          select_token: Select.t() | nil,
          order_token: Order.t() | nil,
          limit_token: Limit.t() | nil,
          query_string: String.t(),
          query_params: map(),
          params_count: non_neg_integer(),
          aliases: map(),
          is_raw: boolean()
        }

  @doc """
  Creates a new query for the informed collection or index

  Returns a `Ravix.RQL.Query` or an `{:error, :query_document_must_be_informed}` if no collection/index was informed

  ## Examples
      iex> Ravix.RQL.Query.from("test")
  """
  @spec from(nil | String.t()) :: {:error, :query_document_must_be_informed} | Query.t()
  def from(nil), do: {:error, :query_document_must_be_informed}

  def from(document) do
    %Query{
      from_token: From.from(document)
    }
  end

  @doc """
  Creates a new query with an alias for the informed collection or index

  Returns a `Ravix.RQL.Query` or an `{:error, :query_document_must_be_informed}` if no collection/index was informed

  ## Examples
      iex> Ravix.RQL.Query.from("test", "t")
  """
  @spec from(nil | String.t(), String.t()) ::
          {:error, :query_document_must_be_informed} | Query.t()
  def from(nil, _), do: {:error, :query_document_must_be_informed}

  def from(document, as_alias) when not is_nil(as_alias) do
    %Query{
      from_token: From.from(document),
      aliases: Map.put(%{}, document, as_alias)
    }
  end

  @doc """
  Adds an update operation to the informed query, it supports a
  `Ravix.RQL.Tokens.Update` token. The token can be created using the following functions:

  `Ravix.RQL.Tokens.Update.set(%Update{}, field, new_value)` to set values
  `Ravix.RQL.Tokens.Update.inc(%Update{}, field, value_to_inc)` to inc values
  `Ravix.RQL.Tokens.Update.dec(%Update{}, field, value_to_dec)` to dec values

  Returns a `Ravix.RQL.Query` with the update operation

  ## Examples
      iex> from = Ravix.RQL.Query.from("cats", "c")
      iex> update = Ravix.RQL.Query.update(from, set(%Update{}, :cat_name, "Fluffer, the hand-ripper"))
  """
  @spec update(Query.t(), Ravix.RQL.Tokens.Update.t()) :: Query.t()
  def update(%Query{} = query, update) do
    %Query{
      query
      | update_token: update
    }
  end

  @doc """
  Adds a where operation with a `Ravix.RQL.Tokens.Condition` to the query

  Returns a `Ravix.RQL.Query` with the where condition

  ## Examples
      iex> from = Ravix.RQL.Query.from("cats", "c")
      iex> where = Ravix.RQL.Query.where(from, equal_to("cat_name", "Meowvius"))
  """
  @spec where(Query.t(), Condition.t()) :: Query.t()
  def where(%Query{} = query, %Condition{} = condition) do
    %Query{
      query
      | where_token: Where.condition(condition)
    }
  end

  @doc """
  Adds a select operation to project fields

  Returns a `Ravix.RQL.Query` with the select condition

  ## Examples
      iex> from = Ravix.RQL.Query.from("cats", "c")
      iex> select = Ravix.RQL.Query.select(from, ["name", "breed"])
  """
  @spec select(Query.t(), Select.allowed_select_params()) :: Query.t()
  def select(%Query{} = query, fields) do
    %Query{
      query
      | select_token: Select.fields(fields)
    }
  end

  @doc """
  Adds a select operation to project fields, leveraging the use of RavenDB Functions

  Returns a `Ravix.RQL.Query` with the select condition

  ## Examples
      iex> from = Ravix.RQL.Query.from("cats", "c")
      iex> select = Ravix.RQL.Query.select_function(from, ooga: "c.name")
  """
  @spec select_function(Query.t(), Keyword.t()) :: Query.t()
  def select_function(%Query{} = query, fields) do
    %Query{
      query
      | select_token: Select.function(fields)
    }
  end

  @doc """
  Adds an `Ravix.RQL.Tokens.And` operation with a `Ravix.RQL.Tokens.Condition` to the query

  Returns a `Ravix.RQL.Query` with the and condition

  ## Examples
      iex> from = Ravix.RQL.Query.from("cats", "c")
      iex> where = Ravix.RQL.Query.where(from, equal_to("cat_name", "Meowvius"))
      iex> and_v = Ravix.RQL.Query.and?(where, equal_to("breed", "Fatto"))
  """
  @spec and?(Query.t(), Condition.t()) :: Query.t()
  def and?(%Query{} = query, %Condition{} = condition) do
    %Query{
      query
      | and_tokens: query.and_tokens ++ [And.condition(condition)]
    }
  end

  @doc """
  Adds an negated `Ravix.RQL.Tokens.And` operation with a `Ravix.RQL.Tokens.Condition` to the query

  Returns a `Ravix.RQL.Query` with the and condition

  ## Examples
      iex> from = Ravix.RQL.Query.from("cats", "c")
      iex> where = Ravix.RQL.Query.where(from, equal_to("cat_name", "Meowvius"))
      iex> and_v = Ravix.RQL.Query.and_not(where, equal_to("breed", "Fatto"))
  """
  @spec and_not(Query.t(), Condition.t()) :: Query.t()
  def and_not(%Query{} = query, %Condition{} = condition) do
    %Query{
      query
      | and_tokens: query.and_tokens ++ [Not.condition(And.condition(condition))]
    }
  end

  @doc """
  Adds an `Ravix.RQL.Tokens.Or` operation with a `Ravix.RQL.Tokens.Condition` to the query

  Returns a `Ravix.RQL.Query` with the and condition

  ## Examples
      iex> from = Ravix.RQL.Query.from("cats", "c")
      iex> where = Ravix.RQL.Query.where(from, equal_to("cat_name", "Meowvius"))
      iex> or_v = Ravix.RQL.Query.or?(where, equal_to("breed", "Fatto"))
  """
  @spec or?(Query.t(), Condition.t()) :: Query.t()
  def or?(%Query{} = query, %Condition{} = condition) do
    %Query{
      query
      | or_tokens: query.or_tokens ++ [Or.condition(condition)]
    }
  end

  @doc """
  Adds a negated `Ravix.RQL.Tokens.Or` operation with a `Ravix.RQL.Tokens.Condition` to the query

  Returns a `Ravix.RQL.Query` with the and condition

  ## Examples
      iex> from = Ravix.RQL.Query.from("cats", "c")
      iex> where = Ravix.RQL.Query.where(from, equal_to("cat_name", "Meowvius"))
      iex> or_v = Ravix.RQL.Query.or_not(where, equal_to("breed", "Fatto"))
  """
  @spec or_not(Query.t(), Condition.t()) :: Query.t()
  def or_not(%Query{} = query, %Condition{} = condition) do
    %Query{
      query
      | or_tokens: query.and_tokens ++ [Not.condition(Or.condition(condition))]
    }
  end

  @doc """
  Adds a `Ravix.RQL.Tokens.Group` operation to the query

  Returns a `Ravix.RQL.Query` with the group_by condition

  ## Examples
      iex> from = Ravix.RQL.Query.from("cats", "c")
      iex> grouped = Ravix.RQL.Query.group_by(from, "breed")
  """
  @spec group_by(Query.t(), String.t() | [String.t()]) :: Query.t()
  def group_by(%Query{} = query, fields) do
    %Query{
      query
      | group_token: Group.by(fields)
    }
  end

  @doc """
  Adds a `Ravix.RQL.Tokens.Limit` operation to the query

  Returns a `Ravix.RQL.Query` with the limit condition

  ## Examples
      iex> from = Ravix.RQL.Query.from("cats", "c")
      iex> limit = Ravix.RQL.Query.limit(from, 5, 10)
  """
  @spec limit(Query.t(), non_neg_integer, non_neg_integer) :: Query.t()
  def limit(%Query{} = query, skip, next) do
    %Query{
      query
      | limit_token: Limit.limit(skip, next)
    }
  end

  @doc """
  Adds a `Ravix.RQL.Tokens.Order` operation to the query

  Returns a `Ravix.RQL.Query` with the ordering condition

  ## Examples
      iex> from = Ravix.RQL.Query.from("cats", "c")
      iex> ordered = Ravix.RQL.Query.order_by(from, [%Order.Field{name: "@metadata.@last-modified", order: :desc, type: :number}])
  """
  @spec order_by(
          Query.t(),
          [Order.Field.t()] | Order.Field.t()
        ) :: Query.t()
  def order_by(%Query{} = query, orders) do
    %Query{
      query
      | order_token: Order.by(orders)
    }
  end

  @doc """
  Create a Query using a raw RQL string

  Returns a `Ravix.RQL.Query` with the raw query

  ## Examples
      iex> raw = Ravix.RQL.Query.raw("from @all_docs where cat_name = \"Fluffers\"")
  """
  @spec raw(String.t()) :: Query.t()
  def raw(raw_query) do
    %Query{
      query_string: raw_query,
      is_raw: true
    }
  end

  @doc """
  Create a Query using a raw RQL string with replaceable placeholders

  Returns a `Ravix.RQL.Query` with the raw query and parameters

  ## Examples
      iex> raw = Ravix.RQL.Query.raw("from @all_docs where cat_name = $p1", %{p1: "Fluffers"})
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
  Executes the query in the informed session and returns the matched documents

  Returns a [RavenDB response](https://ravendb.net/docs/article-page/4.2/java/client-api/rest-api/queries/query-the-database#response-format) map

  ## Examples
      iex> from("Cats")
            |> select("name")
            |> where(equal_to("name", cat.name))
            |> list_all(session_id)
          {:ok, %{
              "DurationInMs" => 62,
              "IncludedPaths" => nil,
              "Includes" => %{},
              "IndexName" => "Auto/Cats/By@metadata.@last-modifiedAndidAndname",
              "IndexTimestamp" => "2022-04-22T20:03:03.8373804",
              "IsStale" => false,
              "LastQueryTime" => "2022-04-22T20:03:04.3475275",
              "LongTotalResults" => 1,
              "NodeTag" => "A",
              "ResultEtag" => 6489530344045176783,
              "Results" => [
                %{
                  "@metadata" => %{
                    "@change-vector" => "A:6445-HJrwf2z3c0G/FHJPm3zK3w",
                    "@id" => "beee79e2-2560-408c-a680-253e9bd7d12e",
                    "@index-score" => 3.079441547393799,
                    "@last-modified" => "2022-04-22T20:03:03.7477980Z",
                    "@projection" => true
                  },
                  "name" => "Lily"
                }
              ],
              "ScannedResults" => 0,
              "SkippedResults" => 0,
              "TotalResults" => 1
            }
          }
  """
  @spec list_all(Query.t(), binary) :: {:error, any} | {:ok, any}
  def list_all(%Query{} = query, session_id) do
    execute_for(query, session_id, :post, false)
  end

  @doc """
  Executes the query in the informed session and returns the matched documents

  Returns a [RavenDB response](https://ravendb.net/docs/article-page/4.2/java/client-api/rest-api/queries/query-the-database#response-format) map

  ## Examples
      iex> stream = from("Cats")
            |> select("name")
            |> where(equal_to("name", cat.name))
            |> stream_all(session_id)

          stream |> Enum.to_list()
          [
              %{
                "@metadata" => %{
                "@change-vector" => "A:6445-HJrwf2z3c0G/FHJPm3zK3w",
                "@id" => "beee79e2-2560-408c-a680-253e9bd7d12e",
                "@index-score" => 3.079441547393799,
                "@last-modified" => "2022-04-22T20:03:03.7477980Z",
                "@projection" => true
              },
              "name" => "Lily"
            }
          ]

  """
  @spec stream_all(Ravix.RQL.Query.t(), binary()) :: any
  def stream_all(%Query{} = query, session_id) do
    execute_for(query, session_id, :get, true)
  end

  @doc """
  Executes the delete query in the informed session

  Returns a [RavenDB response](https://ravendb.net/docs/article-page/5.3/java/client-api/rest-api/queries/delete-by-query#response-format) map

  ## Examples
      iex> from("@all_docs")
            |> where(equal_to("cat_name", any_entity.cat_name))
            |> delete_for(session_id)
          {:ok, %{"OperationId" => 2480, "OperationNodeTag" => "A"}}
  """
  @spec delete_for(Query.t(), binary) :: {:error, any} | {:ok, any}
  def delete_for(%Query{} = query, session_id) do
    execute_for(query, session_id, :delete, false)
  end

  @doc """
  Executes the patch query in the informed session

  Returns a [RavenDB response](https://ravendb.net/docs/article-page/5.3/java/client-api/rest-api/queries/patch-by-query#response-format) map

  ## Examples
      iex> from("@all_docs", "a")
            |> update(set(%Update{}, :cat_name, "Fluffer, the hand-ripper"))
            |> where(equal_to("cat_name", any_entity.cat_name))
            |> update_for(session_id)
          {:ok, %{"OperationId" => 2480, "OperationNodeTag" => "A"}}
  """
  @spec update_for(Query.t(), binary) :: {:error, any} | {:ok, any}
  def update_for(%Query{} = query, session_id) do
    execute_for(query, session_id, :patch, false)
  end

  defp execute_for(%Query{is_raw: false} = query, session_id, method, stream) do
    case QueryParser.parse(query) do
      {:ok, parsed_query} ->
        stream_or_list(parsed_query, session_id, method, stream)

      {:error, err} ->
        {:error, err}
    end
  end

  defp execute_for(%Query{is_raw: true} = query, session_id, method, stream) do
    stream_or_list(query, session_id, method, stream)
  end

  defp stream_or_list(query, session, method, stream) do
    case stream do
      true -> Session.stream_query(query, session)
      false -> Session.execute_query(query, session, method)
    end
  end
end
