defmodule Ravix.RQL.QueryParser do
  require OK
  alias Ravix.RQL.Query

  @spec parse(Query.t()) :: {:error, any} | {:ok, Query.t()}
  def parse(%Query{} = query) do
    OK.for do
      parsed_query =
        query
        |> parse_token(query.from_token)
        |> parse_token(query.where_token)
        |> parse_tokens(query.and_tokens)
        |> parse_tokens(query.or_tokens)
        |> parse_token(query.projection_token)
    after
      parsed_query
    end
  end

  defp parse_tokens({:ok, query}, tokens), do: parse_tokens(query, tokens)

  defp parse_tokens({:error, err}, _),
    do: {:error, err}

  defp parse_tokens(%Query{} = query, []), do: query

  defp parse_tokens(%Query{} = query, tokens) do
    tokens
    |> Enum.reduce(query, fn token, acc ->
      case parse_token(acc, token) do
        {:ok, tokens} -> Map.merge(acc, tokens)
        {:error, err} -> {:error, err}
      end
    end)
  end

  defp parse_token({:ok, query}, tokens), do: parse_token(query, tokens)

  defp parse_token(%Query{} = query, nil), do: query

  defp parse_token({:error, err}, _),
    do: {:error, err}

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
    query_part =
      case condition.token do
        :greater_than ->
          "#{condition.field} > $p#{query.params_count}"

        :eq ->
          "#{condition.field} = $p#{query.params_count}"

        :greater_than_or_eq ->
          "#{condition.field} >= $p#{query.params_count}"

        :lower_than ->
          "#{condition.field} < $p#{query.params_count}"

        :lower_than_or_eq ->
          "#{condition.field} <= $p#{query.params_count}"

        :between ->
          "#{condition.field} between $p#{query.params_count} and $p#{query.params_count + 1}"

        :in ->
          "#{condition.field} in " <>
            "(" <> parse_params_to_positional_string(query, condition.params) <> ")"

        _ ->
          {:error, :invalid_condition_param}
      end

    case query_part do
      {:error, :invalid_condition_param} -> {:error, :invalid_condition_param}
      _ -> {:ok, query_part}
    end
  end

  defp parse_from(%Query{} = query, from_token) do
    {:ok,
     %Query{
       query
       | query_string: query.query_string <> "from #{from_token.document_or_index}"
     }}
  end

  defp parse_from_index(%Query{} = query, from_token) do
    {:ok,
     %Query{
       query
       | query_string: query.query_string <> "from index #{from_token.document_or_index}"
     }}
  end

  defp parse_where(%Query{} = query, where_token) do
    parse_action_token(query, where_token, "where")
  end

  defp parse_and(%Query{} = query, and_token) do
    parse_action_token(query, and_token, "and")
  end

  defp parse_or(%Query{} = query, or_token) do
    parse_action_token(query, or_token, "or")
  end

  defp parse_action_token(%Query{} = query, token, token_string) do
    OK.for do
      condition <- parse_condition_token(query, token.condition)
      positional_params = parse_params_to_positional(query, token.condition.params)
      params_count = query.params_count + length(token.condition.params)

      query_params =
        Map.merge(
          query.query_params,
          positional_params
        )
    after
      %Query{
        query
        | query_string: query.query_string <> " #{token_string} #{condition}",
          query_params: query_params,
          params_count: params_count
      }
    end
  end

  defp parse_params_to_positional(query, params) do
    query.params_count..(query.params_count + length(params) - 1)
    |> Enum.reduce(%{}, fn position, acc ->
      Map.put(acc, "p#{position}", Enum.at(params, position - query.params_count))
    end)
  end

  defp parse_params_to_positional_string(query, params) do
    parse_params_to_positional(query, params)
    |> Map.keys()
    |> Enum.map_join(",", fn key -> "$#{key}" end)
  end
end
