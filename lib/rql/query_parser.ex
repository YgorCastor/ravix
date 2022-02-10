defmodule Ravix.RQL.QueryParser do
  alias Ravix.RQL.Query

  def parse(%Query{} = query) do
    query
    |> parse_token(query.from_token)
    |> parse_token(query.where_token)
    |> parse_tokens(query.and_tokens)
    |> parse_tokens(query.or_tokens)
    |> parse_token(query.projection_token)
  end

  defp parse_tokens(%Query{} = query, []), do: query

  defp parse_tokens(%Query{} = query, tokens) do
    tokens
    |> Enum.reduce(query, fn token, acc ->
      Map.merge(acc, parse_token(acc, token))
    end)
  end

  defp parse_token(%Query{} = query, nil), do: query

  defp parse_token(%Query{} = query, token) do
    case token.token do
      :from -> parse_from(query, token)
      :from_index -> parse_from_index(query, token)
      :where -> parse_where(query, token)
      :and -> parse_and(query, token)
      :or -> parse_or(query, token)
    end
  end

  defp parse_condition_token(%Query{} = query, nil), do: query

  defp parse_condition_token(%Query{} = query, condition) do
    case condition.token do
      :greater_than -> "#{condition.field} > $p#{query.params_count}"
      :eq -> "#{condition.field} = $p#{query.params_count}"
      :greater_than_or_eq -> "#{condition.field} >= $p#{query.params_count}"
      :lower_than -> "#{condition.field} < $p#{query.params_count}"
      :lower_than_or_eq -> "#{condition.field} <= $p#{query.params_count}"
    end
  end

  defp parse_from(%Query{} = query, from_token) do
    %Query{
      query
      | query_string: query.query_string <> "from #{from_token.document_or_index}"
    }
  end

  defp parse_from_index(%Query{} = query, from_token) do
    %Query{
      query
      | query_string: query.query_string <> "from index #{from_token.document_or_index}"
    }
  end

  defp parse_where(%Query{} = query, where_token) do
    %Query{
      query
      | query_string:
          query.query_string <>
            " where #{parse_condition_token(query, where_token.condition)}",
        query_params: add_param(query, where_token.condition.param),
        params_count: query.params_count + 1
    }
  end

  defp parse_and(%Query{} = query, and_token) do
    %Query{
      query
      | query_string:
          query.query_string <> " and #{parse_condition_token(query, and_token.condition)}",
        query_params: add_param(query, and_token.condition.param),
        params_count: query.params_count + 1
    }
  end

  defp parse_or(%Query{} = query, or_token) do
    %Query{
      query
      | query_string:
          query.query_string <> " or #{parse_condition_token(query, or_token.condition)}",
        query_params: add_param(query, or_token.condition.param),
        params_count: query.params_count + 1
    }
  end

  defp add_param(query, param) do
    Map.put(query.query_params, "p#{query.params_count}", param)
  end
end
