import Config

config :ravix, Ravix.Test.Store,
  ssl_config: [
    cert: Ravix.Helpers.Certs.cert_from_b64_to_der(System.get_env("RAVENDB_CLIENT_CERT")),
    key: Ravix.Helpers.Certs.key_from_b64_to_der(System.get_env("RAVENDB_CLIENT_KEY"))
  ]

config :ravix, Ravix.Test.NonRetryableStore,
  ssl_config: [
    cert: Ravix.Helpers.Certs.cert_from_b64_to_der(System.get_env("RAVENDB_CLIENT_CERT")),
    key: Ravix.Helpers.Certs.key_from_b64_to_der(System.get_env("RAVENDB_CLIENT_KEY"))
  ]

config :ravix, Ravix.Test.OptimisticLockStore,
  ssl_config: [
    cert: Ravix.Helpers.Certs.cert_from_b64_to_der(System.get_env("RAVENDB_CLIENT_CERT")),
    key: Ravix.Helpers.Certs.key_from_b64_to_der(System.get_env("RAVENDB_CLIENT_KEY"))
  ]

config :ravix, Ravix.Test.ClusteredStore,
  ssl_config: [
    cert: Ravix.Helpers.Certs.cert_from_b64_to_der(System.get_env("RAVENDB_CLIENT_CERT")),
    key: Ravix.Helpers.Certs.key_from_b64_to_der(System.get_env("RAVENDB_CLIENT_KEY"))
  ]
