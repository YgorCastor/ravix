defmodule Ravix.Factory do
  use ExMachina

  alias Ravix.Documents.Session

  def session_document_factory do
    random_entity = %{id: UUID.uuid4(), something: Faker.Cat.breed()}

    %Session.SessionDocument{
      entity: random_entity,
      key: UUID.uuid4(),
      change_vector: "A:150-fGrQ73YexEqvOBc/0RrYUA",
      metadata: %{
        "@collection": "@empty",
        "@last-modified": "2022-01-24T08:35:28.5915575Z"
      }
    }
  end

  def session_state_factory do
    random_document_id = UUID.uuid4()
    random_deleted_entity = %{id: UUID.uuid4(), something: Faker.Cat.breed()}

    %Session.State{
      session_id: UUID.uuid4(),
      database: Faker.Cat.name(),
      documents_by_id: Map.put(%{}, random_document_id, build(:session_document)),
      defer_commands: [%{key: UUID.uuid4()}],
      deleted_entities: [random_deleted_entity],
      number_of_requests: Enum.random(0..100)
    }
  end
end
