# Frequently Asked Questions

## Can I use LibPQ.jl with Amazon Redshift?

Yes.
However, LibPQ.jl by default sets some client options to make interactions more reliable.
Unsupported options must be disabled for Redshift to allow connections.
To override all options, pass an empty `Dict{String, String}`:

```julia
conn = LibPQ.Connection("dbname=myredshift"; options=Dict{String, String}())
```

## How do I test LibPQ.jl on my own computer?

To test LibPQ.jl you will need access to a PostgreSQL database server with a database called "postgres".
The tests will not make any changes to the database that persist beyond the connection session, even if the tests encounter unforeseen exceptions.
For this reason, it should be safe to use any existing database server.
To set the database user used to connect to the database, use the `LIBPQJL_DATABASE_USER` environment variable.

A simple way to set up a server for testing is to use [Docker](https://hub.docker.com/search/?type=edition&offering=community):

```sh
docker run --detach --name test-libpqjl -p 5432:5432 postgres
```

To set any other client options for connecting to the test database, use the [PostgreSQL environment variables](https://www.postgresql.org/docs/11/libpq-envars.html).
