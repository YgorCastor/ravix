defmodule Ravix.Factory do
  use ExMachina

  alias Ravix.Documents.{Session, Conventions}
  alias Ravix.SampleModel.Cat
  alias Ravix.Connection.{ServerNode, Topology}
  alias Ravix.Connection.State, as: ConnectionState

  def session_document_factory do
    random_entity = %{id: UUID.uuid4(), something: Faker.Cat.breed()}

    %Session.SessionDocument{
      entity: random_entity,
      key: UUID.uuid4(),
      change_vector: "A:150-fGrQ73YexEqvOBc/0RrYUA"
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

  def server_node_factory do
    %ServerNode{
      url: Faker.Internet.url(),
      port: Enum.random(1024..65535),
      protocol: :http,
      database: "test"
    }
  end

  def topology_factory do
    %Topology{
      etag: Faker.Internet.slug(),
      nodes: [build(:server_node)]
    }
  end

  def conventions_factory do
    %Conventions{
      max_number_of_requests_per_session: Enum.random(10..50),
      max_ids_to_catch: Enum.random(128..1024),
      timeout: 1000,
      max_length_of_query_using_get_url: Enum.random(128..1024)
    }
  end

  def network_state_factory do
    %ConnectionState{
      database: "test",
      certificate: "test" |> Base.encode64(),
      certificate_file: nil,
      conventions: build(:conventions)
    }
  end

  def cat_entity_factory do
    %Cat{
      id: UUID.uuid4(),
      name: Faker.Cat.name(),
      breed: Faker.Cat.breed()
    }
  end
end
