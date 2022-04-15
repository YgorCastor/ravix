import Config

config :ravix, Ravix.TestStore,
  urls: [System.get_env("RAVENDB_URL", "http://localhost:8080")],
  database: "test",
  retry_on_failure: false,
  retry_on_stale: false,
  retry_backoff: 100,
  retry_count: 3,
  force_create_database: true,
  document_conventions: %{
    max_number_of_requests_per_session: 30,
    max_ids_to_catch: 32,
    timeout: 30,
    use_optimistic_concurrency: false,
    max_length_of_query_using_get_url: 1024 + 512,
    identity_parts_separator: "/",
    disable_topology_update: false
  }

config :ravix, Ravix.TestStore2,
  urls: [System.get_env("RAVENDB_URL", "http://localhost:8080")],
  database: "test2",
  retry_on_failure: true,
  retry_on_stale: true,
  retry_backoff: 100,
  retry_count: 3,
  force_create_database: true,
  document_conventions: %{
    max_number_of_requests_per_session: 30,
    max_ids_to_catch: 32,
    timeout: 30,
    session_idle_ttl: 3,
    use_optimistic_concurrency: false,
    max_length_of_query_using_get_url: 1024 + 512,
    identity_parts_separator: "/",
    disable_topology_update: false
  }

config :ravix, Ravix.TestStoreInvalid,
  urls: ["http://localhost:9999"],
  database: "test2",
  retry_on_failure: false,
  retry_on_stale: false,
  retry_backoff: 100,
  retry_count: 3,
  force_create_database: true,
  document_conventions: %{
    max_number_of_requests_per_session: 30,
    max_ids_to_catch: 32,
    timeout: 30,
    session_idle_ttl: 3,
    use_optimistic_concurrency: false,
    max_length_of_query_using_get_url: 1024 + 512,
    identity_parts_separator: "/",
    disable_topology_update: false
  }

config :logger, level: :error
