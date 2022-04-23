![ravix_logo](https://user-images.githubusercontent.com/1266053/148282743-79994640-4b15-4ffb-b477-5d0ed18072f9.png)

[![Elixir CI](https://github.com/YgorCastor/ravix/actions/workflows/elixir.yml/badge.svg)](https://github.com/YgorCastor/ravix/actions/workflows/elixir.yml) [![Coverage Status](https://coveralls.io/repos/github/YgorCastor/ravix/badge.svg)](https://coveralls.io/github/YgorCastor/ravix)

# Ravix

Ravix is a in-development project to implement a client for the amazing [RavenDB NoSQL Database](https://ravendb.net/).

# Usage

## Instaling

Add Ravix to your mix.exs dependencies

```elixir
{:ravix, "~> 0.1"}
```

## Setting up your Repository

&nbsp; 

Create a Ravix Store Module for your repository

```elixir
defmodule YourProject.YourStore do
  use Ravix.Documents.Store, otp_app: :your_app
end
```

&nbsp; 

You can configure your Store in your config.exs files

```elixir
config :ravix, Ravix.Test.Store,
  urls: [System.get_env("RAVENDB_URL", "http://localhost:8080")],
  database: "test",
  retry_on_failure: true,
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
```

&nbsp; 

Then you can start the processes in your main supervisor

```elixir
defmodule Ravix.TestApplication do
  use Supervisor

  def init(_opts) do
    children = [
      {Ravix, [%{}]},
      {Ravix.Test.Store, [%{}]} # you can create multiple stores
    ]

    Supervisor.init(
      children,
      strategy: :one_for_one
    )
  end

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
end
```

&nbsp; 

## Querying the Database

&nbsp; 

All operations supported by the driver should be executed inside a session, to open a session you can just call the `open_session/0` function from the store you defined. All the changes are only persisted when the function 
`Ravix.Documents.Session.save_changes/1` is called!

```elixir
iex(2)> Ravix.Test.Store.open_session()
{:ok, "985781c8-9154-494b-92d0-a66b49bb17ee"}
```

### Inserting a new document

```elixir
iex(2)> Ravix.Test.Store.open_session()
iex(2)> {:ok, session_id} = Ravix.Test.Store.open_session()
{:ok, "c4fb1f48-c969-4c76-9b12-5521926c7533"}
iex(3)> Ravix.Documents.Session.store(session_id, %{id: "cat/1", cat_name: "Adolfus"})
{:ok, %{cat_name: "Adolfus", id: "cat/1"}}
iex(4)> Ravix.Documents.Session.save_changes(session_id)
{:ok,
 %{
   "Results" => [
     %{
       "@change-vector" => "A:264-vzsRp+yZT0GDkS5GJY/pAQ",
       "@collection" => "@empty",
       "@id" => "cat/1",
       "@last-modified" => "2022-03-28T15:01:45.6545514Z",
       "Type" => "PUT"
     }
   ]
 }}
```

### Loading a document into the session

```elixir
iex(3)> {:ok, session_id} = Ravix.Test.Store.open_session()
{:ok, "d17e2be8-8c1e-4a59-8626-46725387f769"}
iex(4)> Ravix.Documents.Session.load(session_id, ["cat/1"])
{:ok,
 %{
   "Includes" => %{},
   "Results" => [
     %{
       "@metadata" => %{
         "@change-vector" => "A:264-vzsRp+yZT0GDkS5GJY/pAQ",
         "@id" => "cat/1",
         "@last-modified" => "2022-03-28T15:01:45.6545514Z"
       },
       "cat_name" => "Adolfus",
       "id" => "cat/1"
     }
   ],
   "already_loaded_ids" => []
 }}
```

### Querying using RQL

RavenDB provides a query-language called [RQL](https://ravendb.net/docs/article-page/4.2/csharp/indexes/querying/what-is-rql), and for that Ravix provides two ways to deal with queries, using builder functions and raw RQLs

#### RQL Builder

You can build RQLs using the builder provided by the `Ravix.RQL.Query` module

```elixir
iex(11)> from("@all_docs") |> where(equal_to("cat_name", "Adolfus")) |> list_all(session_id)
{:ok,
 %{
   "DurationInMs" => 1,
   "IncludedPaths" => nil,
   "Includes" => %{},
   "IndexName" => "Auto/AllDocs/Bycat_nameAndid",
   "IndexTimestamp" => "2022-03-28T18:39:58.7637789",
   "IsStale" => false,
   "LastQueryTime" => "2022-03-28T18:49:05.9272430",
   "LongTotalResults" => 1,
   "NodeTag" => "A",
   "ResultEtag" => -4402181509807245325,
   "Results" => [
     %{
       "@metadata" => %{
         "@change-vector" => "A:264-vzsRp+yZT0GDkS5GJY/pAQ",
         "@id" => "cat/1",
         "@index-score" => 5.330733299255371,
         "@last-modified" => "2022-03-28T15:01:45.6545514Z"
       },
       "cat_name" => "Adolfus",
       "id" => "cat/1"
     }
   ],
   "SkippedResults" => 0,
   "TotalResults" => 1
 }}
```

#### Raw Query

```elixir
iex(13)> raw("from @all_docs where cat_name = \"Adolfus\"") |> list_all(session_id)
{:ok,
 %{
   "DurationInMs" => 1,
   "IncludedPaths" => nil,
   "Includes" => %{},
   "IndexName" => "Auto/AllDocs/Bycat_nameAndid",
   "IndexTimestamp" => "2022-03-28T18:39:58.7637789",
   "IsStale" => false,
   "LastQueryTime" => "2022-03-28T18:53:27.4689173",
   "LongTotalResults" => 1,
   "NodeTag" => "A",
   "ResultEtag" => -4402181509807245325,
   "Results" => [
     %{
       "@metadata" => %{
         "@change-vector" => "A:264-vzsRp+yZT0GDkS5GJY/pAQ",
         "@id" => "cat/1",
         "@index-score" => 5.330733299255371,
         "@last-modified" => "2022-03-28T15:01:45.6545514Z"
       },
       "cat_name" => "Adolfus",
       "id" => "cat/1"
     }
   ],
   "SkippedResults" => 0,
   "TotalResults" => 1
 }}
```

### Collections

RavenDB can organize the documents in collections, Ravix will automatically insert the document in a collection if you use the Ravix. Document macro. If you don't want to use the macro, your struct just need to have the `:@metadata` field.

```elixir
defmodule Ravix.SampleModel.Cat do
  use Ravix.Document, fields: [:id, :name, :breed]
end
```

## Secure Server

To connect to a secure server, you can just inform the SSL certificate using the `certificate` or the `certificate_file` configuration.

```elixir
config :ravix, Ravix.Test.Store,
  urls: [System.get_env("RAVENDB_URL", "http://localhost:8080")],
  database: "test",
  certificate: CERT_IN_BASE_64,
  certificate_file: "/opt/certs/cert.pfx"
```

## Ecto
 
What about querying your RavenDB using Ecto? [Ravix-Ecto](https://github.com/YgorCastor/ravix-ecto)

## Current State

* ~~Configuration Reading~~
* ~~Session Management~~
* ~~Request Executors~~
* ~~Unsafe Server Connection~~
* ~~Authenticated Server Connection~~
* ~~Create Document~~
* ~~Delete Document~~
* ~~Load Document~~
* _Queries Engine_ (it works, but i'm not happy)
* ~~Clustering~~
* ~~Topology Updates~~
* Counters
* Timeseries
* Asynchronous Subscriptions
* Attachments

The driver is working for the basic operations, clustering and resiliency are also implemented.

