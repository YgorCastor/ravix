defmodule Ravix.Helpers.RequestBuilderTest do
  use ExUnit.Case
  alias Ravix.Helpers.RequestBuilder

  describe "A request builder" do
    test "should generate a valid url using simple values" do
      url =
        "http://base_url/docs?"
        |> RequestBuilder.append_param("param1", "value1")
        |> RequestBuilder.append_param("param2", 2)

      assert url == "http://base_url/docs?&param1=value1&param2=2"
    end

    test "should generate a valid url using lists" do
      url =
        "http://base_url/docs?"
        |> RequestBuilder.append_param("param1", ["value1", "value2"])
        |> RequestBuilder.append_param("param2", 2)

      assert url == "http://base_url/docs?&param1=value1&param1=value2&param2=2"
    end
  end
end
