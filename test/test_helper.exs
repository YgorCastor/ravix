{:ok, _} = Application.ensure_all_started(:ex_machina, :bypass)

Faker.start()

ExUnit.start(
  exclude: [
    :flaky
  ]
)

defmodule Ravix.Integration.Case do
  use ExUnit.CaseTemplate

  import Ravix.RQL.Query

  setup do
    _ = start_supervised!(Ravix.Test.Store)
    _ = start_supervised!(Ravix.Test.NonRetryableStore)
    _ = start_supervised!(Ravix.Test.OptimisticLockStore)

    {:ok, session_id} = Ravix.Test.Store.open_session()
    {:ok, _} = from("@all_docs") |> delete_for(session_id)
    _ = Ravix.Test.Store.close_session(session_id)

    :ok
  end
end
