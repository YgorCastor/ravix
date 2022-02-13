import Config

config :ravix,
  urls: [System.fetch_env!("RAVENDB_HOST")]
