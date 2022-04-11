{:ok, _} = Application.ensure_all_started(:ex_machina)

Faker.start()
ExUnit.start()

defmodule Ravix.Integration.Case do
  use ExUnit.CaseTemplate

  import Ravix.RQL.Query

  setup do
    _ = start_supervised!(Ravix.TestApplication)

    {:ok, session_id} = Ravix.TestStore.open_session()
    {:ok, _} = from("@all_docs") |> delete_for(session_id)
    _ = Ravix.TestStore.close_session(session_id)

    :ok
  end
end
