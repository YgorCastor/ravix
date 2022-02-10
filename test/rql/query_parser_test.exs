defmodule Ravix.RQL.QueryParserTest do
  use ExUnit.Case

  import Ravix.RQL.Query
  import Ravix.RQL.Tokens.Condition

  alias Ravix.RQL.QueryParser

  describe "parse/1" do
    test "It should parse the tokens succesfully" do
      query_result =
        from("test")
        |> where(greater_than("field", 10))
        |> and?(equal_to("field2", "asdf"))
        |> or?(greater_than_or_equal_to("field3", 20))
        |> QueryParser.parse()

      assert query_result.query_string ==
               "from test where field > $p0 and field2 = $p1 or field3 >= $p2"

      assert query_result.query_params["p0"] == 10
      assert query_result.query_params["p1"] == "asdf"
      assert query_result.query_params["p2"] == 20

      assert query_result.params_count == 3
      assert query_result.is_raw == false
    end
  end
end
