defmodule Ravix.RQL.QueryParserTest do
  use ExUnit.Case

  import Ravix.RQL.Query
  import Ravix.RQL.Tokens.Condition

  alias Ravix.RQL.QueryParser
  alias Ravix.RQL.Tokens.Condition

  describe "parse/1" do
    test "It should parse the tokens succesfully" do
      {:ok, query_result} =
        from("test")
        |> where(greater_than("field", 10))
        |> and?(equal_to("field2", "asdf"))
        |> or?(greater_than_or_equal_to("field3", 20))
        |> or?(in?("field4", ["a", "b", "c"]))
        |> and?(between("field5", [15, 25]))
        |> limit(2, 3)
        |> QueryParser.parse()

      assert query_result.query_string ==
               "from test where field > $p0 and field2 = $p1 and field5 between $p2 and $p3 or field3 >= $p4 or field4 in ($p5,$p6,$p7) limit 2, 3"

      assert query_result.query_params["p0"] == 10
      assert query_result.query_params["p1"] == "asdf"
      assert query_result.query_params["p2"] == 15
      assert query_result.query_params["p3"] == 25
      assert query_result.query_params["p4"] == 20
      assert query_result.query_params["p5"] == "a"
      assert query_result.query_params["p6"] == "b"
      assert query_result.query_params["p7"] == "c"

      assert query_result.params_count == 8
      assert query_result.is_raw == false
    end

    test "An invalid condition should return an error" do
      {:error, :invalid_condition_param} =
        from("test") |> where(%Condition{token: :invalid}) |> QueryParser.parse()
    end

    test "Should parse an update succesfully" do
      {:ok, query_result} =
        from("test", "t")
        |> where(greater_than("field", 10))
        |> and?(equal_to("field2", "asdf"))
        |> update(%{field: "new_value", field2: "new_value_2"})
        |> QueryParser.parse()

      assert query_result.query_string ==
               "from test as t where t.field > $p0 and t.field2 = $p1 update{ t.field = $p2, t.field2 = $p3 }"

      assert query_result.query_params["p0"] == 10
      assert query_result.query_params["p1"] == "asdf"
      assert query_result.query_params["p2"] == "new_value"
      assert query_result.query_params["p3"] == "new_value_2"

      assert query_result.params_count == 4
      assert query_result.is_raw == false
    end
  end
end
