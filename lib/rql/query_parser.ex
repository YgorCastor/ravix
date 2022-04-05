defmodule Ravix.RQL.QueryParser do
  @moduledoc """
  Parsing tokens to RQL
  """

  require OK
  alias Ravix.RQL.Query

  @doc """
  Receives a `Ravix.RQL.Query` object and parses it to a RQL query string
  """
  @spec parse(Query.t()) :: {:error, any} | {:ok, Query.t()}
  def parse(%Query{} = query) do
    OK.for do
      parsed_query =
        query
        |> parse_stmt(query.from_token)
        |> parse_stmt(query.where_token)
        |> parse_stmts(query.and_tokens)
        |> parse_stmts(query.or_tokens)
        |> parse_stmt(query.projection_token)
        |> parse_stmt(query.update_token)
        |> parse_stmt(query.limit_token)
    after
      parsed_query
    end
  end

  defp parse_stmts({:ok, query}, stmts), do: parse_stmts(query, stmts)

  defp parse_stmts({:error, err}, _),
    do: {:error, err}

  defp parse_stmts(%Query{} = query, []), do: query

  defp parse_stmts(%Query{} = query, stmts) do
    stmts
    |> Enum.reduce(query, fn stmt, acc ->
      case parse_stmt(acc, stmt) do
        {:ok, stmts} -> Map.merge(acc, stmts)
        {:error, err} -> {:error, err}
      end
    end)
  end

  defp parse_stmt({:ok, query}, stmt), do: parse_stmt(query, stmt)

  defp parse_stmt(%Query{} = query, nil), do: query

  defp parse_stmt({:error, err}, _),
    do: {:error, err}

  defp parse_stmt(%Query{} = query, stmt) do
    case stmt.token do
      :from -> parse_from(query, stmt)
      :from_index -> parse_from_index(query, stmt)
      :update -> parse_update(query, stmt)
      :where -> parse_where(query, stmt)
      :and -> parse_and(query, stmt)
      :or -> parse_or(query, stmt)
      :limit -> parse_limit(query, stmt)
      _ -> {:error, :invalid_statement}
    end
  end

  defp parse_condition_stmt(%Query{} = query, nil), do: query

  defp parse_condition_stmt(%Query{} = query, condition) do
    query_part =
      case condition.token do
        :greater_than ->
          "#{parse_field(query, condition.field)} > $p#{query.params_count}"

        :eq ->
          "#{parse_field(query, condition.field)} = $p#{query.params_count}"

        :greater_than_or_eq ->
          "#{parse_field(query, condition.field)} >= $p#{query.params_count}"

        :lower_than ->
          "#{parse_field(query, condition.field)} < $p#{query.params_count}"

        :lower_than_or_eq ->
          "#{parse_field(query, condition.field)} <= $p#{query.params_count}"

        :between ->
          "#{parse_field(query, condition.field)} between $p#{query.params_count} and $p#{query.params_count + 1}"

        :in ->
          "#{parse_field(query, condition.field)} in " <>
            "(" <> parse_params_to_positional_string(query, condition.params) <> ")"

        :nin ->
          "#{parse_field(query, condition.field)} not in " <>
            "(" <> parse_params_to_positional_string(query, condition.params) <> ")"

        :ne ->
          "#{parse_field(query, condition.field)} != $p#{query.params_count}"

        :not ->
          "not #{parse_condition_stmt(query, condition.field)}"

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
       | query_string:
           query.query_string <>
             "from #{from_token.document_or_index}" <>
             parse_alias(query, from_token.document_or_index)
     }}
  end

  defp parse_from_index(%Query{} = query, from_token) do
    {:ok,
     %Query{
       query
       | query_string:
           query.query_string <>
             "from index #{from_token.document_or_index}" <>
             parse_alias(query, from_token.document_or_index)
     }}
  end

  defp parse_update(%Query{} = query, update_token) do
    fields_to_update =
      update_token.fields
      |> Map.keys()
      |> Enum.reduce(%{updates: [], current_position: query.params_count}, fn field, acc ->
        %{
          acc
          | updates: acc.updates ++ ["#{parse_field(query, field)} = $p#{acc.current_position}"],
            current_position: acc.current_position + 1
        }
      end)

    positional_params = parse_params_to_positional(query, Map.values(update_token.fields))

    query_params =
      Map.merge(
        query.query_params,
        positional_params
      )

    {:ok,
     %Query{
       query
       | query_string:
           query.query_string <>
             " update{ " <> Enum.join(fields_to_update.updates, ", ") <> " }",
         query_params: query_params,
         params_count: fields_to_update.current_position
     }}
  end

  defp parse_where(%Query{} = query, where_token) do
    parse_locator_stmt(query, where_token, "where")
  end

  defp parse_and(%Query{} = query, and_token) do
    parse_locator_stmt(query, and_token, "and")
  end

  defp parse_or(%Query{} = query, or_token) do
    parse_locator_stmt(query, or_token, "or")
  end

  defp parse_limit(%Query{} = query, limit_token) do
    {:ok,
     %Query{
       query
       | query_string:
           query.query_string <>
             " limit #{limit_token.skip}, #{limit_token.next}"
     }}
  end

  defp parse_locator_stmt(%Query{} = query, stmt, locator) do
    OK.for do
      condition <- parse_condition_stmt(query, stmt.condition)
      positional_params = parse_params_to_positional(query, stmt.condition.params)
      params_count = query.params_count + length(stmt.condition.params)

      query_params =
        Map.merge(
          query.query_params,
          positional_params
        )
    after
      %Query{
        query
        | query_string: query.query_string <> " #{locator} #{condition}",
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

  defp parse_alias(%Query{aliases: aliases}, document) do
    case Map.has_key?(aliases, document) do
      true -> " as " <> Map.get(aliases, document)
      false -> ""
    end
  end

  defp parse_field(%Query{aliases: aliases, from_token: from_token}, field) do
    case Map.has_key?(aliases, from_token.document_or_index) do
      true -> Map.get(aliases, from_token.document_or_index) <> ".#{field}"
      false -> field
    end
  end
end
