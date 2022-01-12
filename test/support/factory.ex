defmodule Ravix.Factory do
  use ExMachina

  alias Ravix.Documents.Session

  def session_state_factory do
    random_document_id = UUID.uuid4()
    random_entity = %{id: UUID.uuid4(), something: Faker.Cat.breed()}
    random_deleted_entity = %{id: UUID.uuid4(), something: Faker.Cat.breed()}

    %Session.State{
      session_id: UUID.uuid4(),
      database: Faker.Cat.name(),
      documents_by_id: Map.put(%{}, random_document_id, %{foo: "bar"}),
      documents_by_entity: Map.put(%{}, random_entity, %{}),
      included_documents_by_id: [UUID.uuid4()],
      known_missing_ids: [UUID.uuid4()],
      defer_commands: [%{key: UUID.uuid4()}],
      deleted_entities: [random_deleted_entity],
      number_of_requests: Enum.random(0..100)
    }
  end
end
