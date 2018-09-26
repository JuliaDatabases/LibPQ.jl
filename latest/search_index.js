var documenterSearchIndex = {"docs": [

{
    "location": "index.html#",
    "page": "Home",
    "title": "Home",
    "category": "page",
    "text": ""
},

{
    "location": "index.html#LibPQ-1",
    "page": "Home",
    "title": "LibPQ",
    "category": "section",
    "text": "(Image: Stable) (Image: Latest) (Image: Build Status) (Image: CodeCov)"
},

{
    "location": "index.html#Examples-1",
    "page": "Home",
    "title": "Examples",
    "category": "section",
    "text": ""
},

{
    "location": "index.html#Selection-1",
    "page": "Home",
    "title": "Selection",
    "category": "section",
    "text": "using LibPQ, DataStreams, NamedTuples\n\nconn = LibPQ.Connection(\"dbname=postgres\")\nresult = execute(conn, \"SELECT typname FROM pg_type WHERE oid = 16\")\ndata = Data.stream!(result, NamedTuple)\n\n# the same but with parameters\nresult = execute(conn, \"SELECT typname FROM pg_type WHERE oid = \\$1\", [\"16\"])\ndata = Data.stream!(result, NamedTuple)\n\n# the same but using `fetch!` to handle streaming and clearing\ndata = fetch!(NamedTuple, execute(conn, \"SELECT typname FROM pg_type WHERE oid = \\$1\", [\"16\"]))\n\nclose(conn)"
},

{
    "location": "index.html#Insertion-1",
    "page": "Home",
    "title": "Insertion",
    "category": "section",
    "text": "using LibPQ, DataStreams\n\nconn = LibPQ.Connection(\"dbname=postgres user=$DATABASE_USER\")\n\nresult = execute(conn, \"\"\"\n    CREATE TEMPORARY TABLE libpqjl_test (\n        no_nulls    varchar(10) PRIMARY KEY,\n        yes_nulls   varchar(10)\n    );\n\"\"\")\n\nData.stream!(\n    data,\n    LibPQ.Statement,\n    conn,\n    \"INSERT INTO libpqjl_test (no_nulls, yes_nulls) VALUES (\\$1, \\$2);\",\n)\n\nclose(conn)"
},

{
    "location": "index.html#A-Note-on-Bulk-Insertion-1",
    "page": "Home",
    "title": "A Note on Bulk Insertion",
    "category": "section",
    "text": "When inserting a large number of rows, wrapping your insert queries in a transaction will greatly increase performance. See the PostgreSQL documentation 14.4.1. Disable Autocommit for more information.Concretely, this means surrounding your query like this:execute(conn, \"BEGIN;\")\n\nData.stream!(\n    data,\n    LibPQ.Statement,\n    conn,\n    \"INSERT INTO libpqjl_test (no_nulls, yes_nulls) VALUES (\\$1, \\$2);\",\n)\n\nexecute(conn, \"COMMIT;\")"
},

{
    "location": "pages/type-conversions.html#",
    "page": "Type Conversions",
    "title": "Type Conversions",
    "category": "page",
    "text": ""
},

{
    "location": "pages/type-conversions.html#typeconv-1",
    "page": "Type Conversions",
    "title": "Type Conversions",
    "category": "section",
    "text": "The implementation of type conversions across the LibPQ.jl interface is sufficiently complicated that it warrants its own section in the documentation. Luckily, it should be easy to use for whichever case you need.DocTestSetup = quote\n    using LibPQ\n    using DataFrames\n    isdefined(Base, :NamedTuple) || using NamedTuples\n\n    DATABASE_USER = get(ENV, \"LIBPQJL_DATABASE_USER\", \"postgres\")\n    conn = LibPQ.Connection(\"dbname=postgres user=$DATABASE_USER\")\nend"
},

{
    "location": "pages/type-conversions.html#From-Julia-to-PostgreSQL-1",
    "page": "Type Conversions",
    "title": "From Julia to PostgreSQL",
    "category": "section",
    "text": "Currently all types are printed to strings and given to LibPQ as such, with no special treatment. Expect this to change in a future release. For now, you can convert the data to strings yourself before passing to execute. This should only be necessary for data types whose Julia string representation is not valid in PostgreSQL, such as arrays.julia> A = collect(12:15);\n\njulia> nt = fetch!(NamedTuple, execute(conn, \"SELECT \\$1 = ANY(\\$2) AS result\", Any[13, string(\"{\", join(A, \",\"), \"}\")]));\n\njulia> nt[:result][1]\ntrue"
},

{
    "location": "pages/type-conversions.html#From-PostgreSQL-to-Julia-1",
    "page": "Type Conversions",
    "title": "From PostgreSQL to Julia",
    "category": "section",
    "text": "The default type conversions applied when fetching PostgreSQL data should be sufficient in many cases.julia> df = fetch!(DataFrame, execute(conn, \"SELECT 1::int4, \'foo\'::varchar, \'{1.0, 2.1, 3.3}\'::float8[], false, TIMESTAMP \'2004-10-19 10:23:54\'\"))\n1×5 DataFrames.DataFrame\n│ Row │ int4 │ varchar │ float8          │ bool  │ timestamp           │\n├─────┼──────┼─────────┼─────────────────┼───────┼─────────────────────┤\n│ 1   │ 1    │ foo     │ [1.0, 2.1, 3.3] │ false │ 2004-10-19T10:23:54 │The column types in Julia for the above DataFrame are Int32, String, Vector{Float64}, Bool, and DateTime.Any unknown or unsupported types are parsed as Strings by default."
},

{
    "location": "pages/type-conversions.html#NULL-1",
    "page": "Type Conversions",
    "title": "NULL",
    "category": "section",
    "text": "The PostgreSQL NULL is handled with missing. By default, data streamed using DataStreams is Union{T, Missing}, and columns are Vector{Union{T, Missing}}. While libpq does not provide an interface for checking whether a result column contains NULL, it\'s possible to assert that columns do not contain NULL using the not_null keyword argument to execute. This will result in data retrieved as T/Vector{T} instead. not_null accepts a list of column names or column positions, or a Bool asserting that all columns do or do not have the possiblity of NULL.The type-related interfaces described below only deal with the T part of the Union{T, Missing}, and there is currently no way to use an alternate NULL representation."
},

{
    "location": "pages/type-conversions.html#Overrides-1",
    "page": "Type Conversions",
    "title": "Overrides",
    "category": "section",
    "text": "It\'s possible to override the default type conversion behaviour in several places. Refer to the Implementation section for more detailed information."
},

{
    "location": "pages/type-conversions.html#Query-level-1",
    "page": "Type Conversions",
    "title": "Query-level",
    "category": "section",
    "text": "There are three arguments to execute for this:column_types argument to set the desired types for given columns. This is accepted as a dictionary mapping column names (as Symbols or Strings) and/or positions (as Integers) to Julia types.\ntype_map argument to set the mapping from PostgreSQL types to Julia types. This is accepted as a dictionary mapping PostgreSQL oids (as Integers) or canonical type names (as Symbols or Strings) to Julia types.\nconversions argument to set the function used to convert from a given PostgreSQL type to a given Julia type. This is accepted as a dictionary mapping 2-tuples of PostgreSQL oids or type names (as above) and Julia types to callables (functions or type constructors)."
},

{
    "location": "pages/type-conversions.html#Connection-level-1",
    "page": "Type Conversions",
    "title": "Connection-level",
    "category": "section",
    "text": "LibPQ.Connection supports type_map and conversions arguments as well, which will apply to all queries run with the created connection. Query-level overrides will override connection-level overrides."
},

{
    "location": "pages/type-conversions.html#Global-1",
    "page": "Type Conversions",
    "title": "Global",
    "category": "section",
    "text": "To override behaviour for every query everywhere, add mappings to the global constants LibPQ.LIBPQ_TYPE_MAP and LibPQ.LIBPQ_CONVERSIONS. Connection-level overrides will override these global overrides."
},

{
    "location": "pages/type-conversions.html#Implementation-1",
    "page": "Type Conversions",
    "title": "Implementation",
    "category": "section",
    "text": ""
},

{
    "location": "pages/type-conversions.html#Flow-1",
    "page": "Type Conversions",
    "title": "Flow",
    "category": "section",
    "text": "When a LibPQ.Result is created (as the result of running a query), the Julia types and conversion functions for each column are precalculated and stored within the Result. The types are chosen using these sources, in decreasing priority:column_types overrides at Result level\ntype_map overrides at Result level\ntype_map overrides at Connection level\nLibPQ.LIBPQ_TYPE_MAP\nLibPQ._DEFAULT_TYPE_MAP\nfallback to StringUsing those types, the function for converting from PostgreSQL data to Julia data is selected, using these sources, in decreasing priority:conversions overrides at Result level\nconversions overrides at Connection level\nLibPQ.LIBPQ_CONVERSIONS\nLibPQ._DEFAULT_CONVERSIONS,\nfallback to parseWhen fetching a particular value from a Result, that function is used to turn data wrapped by a PQValue to a Julia type. This operation always copies or parses data and never provides a view into the original Result."
},

{
    "location": "pages/type-conversions.html#canon-1",
    "page": "Type Conversions",
    "title": "Canonical PostgreSQL Type Names",
    "category": "section",
    "text": "While PostgreSQL allows many aliases for its types (e.g., double precision for float8 and character varying for varchar), there is one \"canonical\" name for the type stored in the pg_type table from PostgreSQL\'s catalog. You can find a list of these for all of PostgreSQL\'s default types in the keys of LibPQ.PQ_SYSTEM_TYPES.DocTestSetup = nothing"
},

{
    "location": "pages/api.html#",
    "page": "API",
    "title": "API",
    "category": "page",
    "text": ""
},

{
    "location": "pages/api.html#LibPQ-API-1",
    "page": "API",
    "title": "LibPQ API",
    "category": "section",
    "text": "DocTestSetup = quote\n    using LibPQ\nend"
},

{
    "location": "pages/api.html#Public-1",
    "page": "API",
    "title": "Public",
    "category": "section",
    "text": ""
},

{
    "location": "pages/api.html#LibPQ.Connection",
    "page": "API",
    "title": "LibPQ.Connection",
    "category": "type",
    "text": "mutable struct Connection\n\nA connection to a PostgreSQL database.\n\nFields:\n\nconn\nA pointer to a libpq PGconn object (C_NULL if closed)\nencoding\nlibpq client encoding (string encoding of returned data)\nuid_counter\nInteger counter for generating connection-level unique identifiers\ntype_map\nConnection-level type correspondence map\nfunc_map\nConnection-level conversion functions\nclosed\nTrue if the connection is closed and the PGconn object has been cleaned up\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.execute",
    "page": "API",
    "title": "LibPQ.execute",
    "category": "function",
    "text": "execute(\n    {jl_conn::Connection, query::AbstractString | stmt::Statement},\n    [parameters::AbstractVector,]\n    throw_error::Bool=true,\n    column_types::AbstractDict=ColumnTypeMap(),\n    type_map::AbstractDict=LibPQ.PQTypeMap(),\n    conversions::AbstractDict=LibPQ.PQConversions(),\n) -> Result\n\nRun a query on the PostgreSQL database and return a Result. If throw_error is true, throw an error and clear the result if the query results in a fatal error or unreadable response.\n\nThe query may be passed as Connection and AbstractString (SQL) arguments, or as a Statement.\n\nexecute optionally takes a parameters vector which passes query parameters as strings to PostgreSQL.\n\ncolumn_types accepts type overrides for columns in the result which take priority over those in type_map. For information on the column_types, type_map, and conversions arguments, see Type Conversions.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.prepare",
    "page": "API",
    "title": "LibPQ.prepare",
    "category": "function",
    "text": "prepare(jl_conn::Connection, query::AbstractString) -> Statement\n\nCreate a prepared statement on the PostgreSQL server using libpq. The statement is given an generated unique name using unique_id.\n\nnote: Note\nCurrently the statement is not explicitly deallocated, but it is deallocated at the end of session per the PostgreSQL documentation on DEALLOCATE.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.status-Tuple{LibPQ.Connection}",
    "page": "API",
    "title": "LibPQ.status",
    "category": "method",
    "text": "status(jl_conn::Connection) -> libpq_c.ConnStatusType\n\nReturn the status of the PostgreSQL database connection according to libpq. Only CONNECTION_OK and CONNECTION_BAD are valid for blocking connections, and only blocking connections are supported right now.\n\nSee also: error_message\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Base.close-Tuple{LibPQ.Connection}",
    "page": "API",
    "title": "Base.close",
    "category": "method",
    "text": "close(jl_conn::Connection)\n\nClose the PostgreSQL database connection and free the memory used by the PGconn object. This function calls PQfinish, but only if jl_conn.closed is false, to avoid a double-free.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Base.isopen-Tuple{LibPQ.Connection}",
    "page": "API",
    "title": "Base.isopen",
    "category": "method",
    "text": "isopen(jl_conn::Connection) -> Bool\n\nCheck whether a connection is open.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.reset!-Tuple{LibPQ.Connection}",
    "page": "API",
    "title": "LibPQ.reset!",
    "category": "method",
    "text": "reset!(jl_conn::Connection; throw_error=true)\n\nReset the communication to the PostgreSQL server. The PGconn object will be recreated using identical connection parameters.\n\nSee handle_new_connection for information on the throw_error argument.\n\nnote: Note\nThis function can be called on a connection with status CONNECTION_BAD, for example, but cannot be called on a connection that has been closed.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Base.show-Tuple{IO,LibPQ.Connection}",
    "page": "API",
    "title": "Base.show",
    "category": "method",
    "text": "show(io::IO, jl_conn::Connection)\n\nDisplay a Connection by showing the connection status and each connection option.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Connections-1",
    "page": "API",
    "title": "Connections",
    "category": "section",
    "text": "LibPQ.Connection\nexecute\nprepare\nstatus(::LibPQ.Connection)\nBase.close(::LibPQ.Connection)\nBase.isopen(::LibPQ.Connection)\nreset!(::LibPQ.Connection)\nBase.show(::IO, ::LibPQ.Connection)"
},

{
    "location": "pages/api.html#LibPQ.Result",
    "page": "API",
    "title": "LibPQ.Result",
    "category": "type",
    "text": "mutable struct Result <: DataStreams.Data.Source\n\nA result from a PostgreSQL database query\n\nFields:\n\nresult\nA pointer to a libpq PGresult object (C_NULL if cleared)\ncolumn_oids\nPostgreSQL Oids for each column in the result\ncolumn_types\nJulia types for each column in the result\nnot_null\nWhether to expect NULL for each column (whether output data can have missing)\ncolumn_funcs\nConversions from PostgreSQL data to Julia types for each column in the result\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.status-Tuple{LibPQ.Result}",
    "page": "API",
    "title": "LibPQ.status",
    "category": "method",
    "text": "status(jl_result::Result) -> libpq_c.ExecStatusType\n\nReturn the status of a result\'s corresponding database query according to libpq. Only CONNECTION_OK and CONNECTION_BAD are valid for blocking connections, and only blocking connections are supported right now.\n\nSee also: error_message\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Base.close-Tuple{LibPQ.Result}",
    "page": "API",
    "title": "Base.close",
    "category": "method",
    "text": "close(jl_result::Result)\n\nClean up the memory used by the PGresult object. The Result will no longer be usable.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Base.isopen-Tuple{LibPQ.Result}",
    "page": "API",
    "title": "Base.isopen",
    "category": "method",
    "text": "isopen(jl_result::Result)\n\nDetermine whether the given Result has been closed, i.e. whether the memory associated with the underlying PGresult object has been cleared.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.num_rows-Tuple{LibPQ.Result}",
    "page": "API",
    "title": "LibPQ.num_rows",
    "category": "method",
    "text": "num_rows(jl_result::Result) -> Int\n\nReturn the number of rows in the query result. This will be 0 if the query would never return data.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.num_columns-Tuple{LibPQ.Result}",
    "page": "API",
    "title": "LibPQ.num_columns",
    "category": "method",
    "text": "num_columns(jl_result::Result) -> Int\n\nReturn the number of columns in the query result. This will be 0 if the query would never return data.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.num_affected_rows-Tuple{LibPQ.Result}",
    "page": "API",
    "title": "LibPQ.num_affected_rows",
    "category": "method",
    "text": "num_affected_rows(jl_result::Result) -> Int\n\nReturn the number of rows affected by the command returning the result. This is useful for counting the rows affected by operations such as INSERT, UPDATE and DELETE that do not return rows but affect them. This will be 0 if the query does not affect any row.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Base.show-Tuple{IO,LibPQ.Result}",
    "page": "API",
    "title": "Base.show",
    "category": "method",
    "text": "show(io::IO, jl_result::Result)\n\nShow a PostgreSQL result and whether it has been cleared.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Results-1",
    "page": "API",
    "title": "Results",
    "category": "section",
    "text": "LibPQ.Result\nstatus(::LibPQ.Result)\nBase.close(::LibPQ.Result)\nBase.isopen(::LibPQ.Result)\nnum_rows(::LibPQ.Result)\nnum_columns(::LibPQ.Result)\nnum_affected_rows(::LibPQ.Result)\nBase.show(::IO, ::LibPQ.Result)"
},

{
    "location": "pages/api.html#LibPQ.Statement",
    "page": "API",
    "title": "LibPQ.Statement",
    "category": "type",
    "text": "struct Statement\n\nA PostgreSQL prepared statement\n\nFields:\n\njl_conn\nA Connection for which this statement is valid. It may become invalid if the connection is reset.\n\nname\nAn autogenerated neame for the prepared statement (using unique_id\nquery\nThe query string of the prepared statement\ndescription\nA Result containing a description of the prepared statement\nnum_params\nThe number of parameters accepted by this statement according to description\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.num_columns-Tuple{LibPQ.Statement}",
    "page": "API",
    "title": "LibPQ.num_columns",
    "category": "method",
    "text": "num_columns(stmt::Statement) -> Int\n\nReturn the number of columns that would be returned by executing the prepared statement.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.num_params-Tuple{LibPQ.Statement}",
    "page": "API",
    "title": "LibPQ.num_params",
    "category": "method",
    "text": "num_params(stmt::Statement) -> Int\n\nReturn the number of parameters in the prepared statement.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Base.show-Tuple{IO,LibPQ.Statement}",
    "page": "API",
    "title": "Base.show",
    "category": "method",
    "text": "show(io::IO, jl_result::Statement)\n\nShow a PostgreSQL prepared statement and its query.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Statements-1",
    "page": "API",
    "title": "Statements",
    "category": "section",
    "text": "LibPQ.Statement\nnum_columns(::LibPQ.Statement)\nnum_params(::LibPQ.Statement)\nBase.show(::IO, ::LibPQ.Statement)"
},

{
    "location": "pages/api.html#LibPQ.Statement-Tuple{DataStreams.Data.Schema,Type{DataStreams.Data.Row},Bool,LibPQ.Connection,AbstractString}",
    "page": "API",
    "title": "LibPQ.Statement",
    "category": "method",
    "text": "Statement(sch::Data.Schema, ::Type{Data.Row}, append, connection::Connection, query::AbstractString) -> Statement\n\nConstruct a Statement for use in streaming with DataStreams. This function is called by Data.stream!(source, Statement, connection, query).\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.fetch!",
    "page": "API",
    "title": "LibPQ.fetch!",
    "category": "function",
    "text": "fetch!(sink::Union{T, Type{T}}, result::Result, args...; kwargs...) where {T} -> T\n\nStream data to sink or a new structure of type T using Data.stream!. Any trailing args or kwargs are passed to Data.stream!. result is cleared upon completion.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#DataStreams-Integration-1",
    "page": "API",
    "title": "DataStreams Integration",
    "category": "section",
    "text": "LibPQ.Statement(::LibPQ.DataStreams.Data.Schema, ::Type{LibPQ.DataStreams.Data.Row}, ::Bool, ::LibPQ.Connection, ::AbstractString)\nLibPQ.fetch!"
},

{
    "location": "pages/api.html#Internals-1",
    "page": "API",
    "title": "Internals",
    "category": "section",
    "text": ""
},

{
    "location": "pages/api.html#LibPQ.handle_new_connection",
    "page": "API",
    "title": "LibPQ.handle_new_connection",
    "category": "function",
    "text": "handle_new_connection(jl_conn::Connection; throw_error=true) -> Connection\n\nCheck status and handle errors for newly-created connections. Also set the client encoding (23.3. Character Set Support) to jl_conn.encoding.\n\nIf throw_error is true, an error will be thrown if the connection\'s status is CONNECTION_BAD and the PGconn object will be cleaned up. Otherwise, a warning will be shown and the user should call close or reset! on the returned Connection.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.server_version",
    "page": "API",
    "title": "LibPQ.server_version",
    "category": "function",
    "text": "server_version(jl_conn::Connection) -> VersionNumber\n\nGet the PostgreSQL version of the server.\n\nSee 33.2. Connection Status Functions for information on the integer returned by PQserverVersion that is parsed by this function.\n\nSee @pqv_str for information on how this packages represents PostgreSQL version numbers.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.encoding",
    "page": "API",
    "title": "LibPQ.encoding",
    "category": "function",
    "text": "encoding(jl_conn::Connection) -> String\n\nReturn the client encoding name for the current connection (see Table 23.1. PostgreSQL Character Sets for possible values).\n\nCurrently all Julia connections are set to use UTF8 as this makes conversion to and from String straighforward.\n\nSee also: set_encoding!, reset_encoding!\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.set_encoding!",
    "page": "API",
    "title": "LibPQ.set_encoding!",
    "category": "function",
    "text": "set_encoding!(jl_conn::Connection, encoding::String)\n\nSet the client encoding for the current connection (see Table 23.1. PostgreSQL Character Sets for possible values).\n\nCurrently all Julia connections are set to use UTF8 as this makes conversion to and from String straighforward. Other encodings are not explicitly handled by this package and will probably be very buggy.\n\nSee also: encoding, reset_encoding!\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.reset_encoding!",
    "page": "API",
    "title": "LibPQ.reset_encoding!",
    "category": "function",
    "text": "reset_encoding!(jl_conn::Connection, encoding::String)\n\nReset the client encoding for the current connection to jl_conn.encoding.\n\nSee also: encoding, set_encoding!\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.transaction_status",
    "page": "API",
    "title": "LibPQ.transaction_status",
    "category": "function",
    "text": "transaction_status(jl_conn::Connection) -> libpq_c.PGTransactionStatusType\n\nReturn the PostgreSQL database server\'s current in-transaction status for the connection. See  for information on the meaning of the possible return values.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.unique_id",
    "page": "API",
    "title": "LibPQ.unique_id",
    "category": "function",
    "text": "unique_id(jl_conn::Connection, prefix::AbstractString=\"\") -> String\n\nReturn a valid PostgreSQL identifier that is unique for the current connection. This is mostly used to create names for prepared statements.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.error_message-Tuple{LibPQ.Connection}",
    "page": "API",
    "title": "LibPQ.error_message",
    "category": "method",
    "text": "error_message(jl_conn::Connection) -> String\n\nReturn the error message most recently generated by an operation on the connection. Includes a trailing newline.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Connections-2",
    "page": "API",
    "title": "Connections",
    "category": "section",
    "text": "LibPQ.handle_new_connection\nLibPQ.server_version\nLibPQ.encoding\nLibPQ.set_encoding!\nLibPQ.reset_encoding!\nLibPQ.transaction_status\nLibPQ.unique_id\nLibPQ.error_message(::LibPQ.Connection)"
},

{
    "location": "pages/api.html#LibPQ.ConnectionOption",
    "page": "API",
    "title": "LibPQ.ConnectionOption",
    "category": "type",
    "text": "struct ConnectionOption\n\nA Julia representation of a PostgreSQL connection option (PQconninfoOption).\n\nFields:\n\nkeyword\nThe name of the option\nenvvar\nThe name of the fallback environment variable for this option\ncompiled\nThe PostgreSQL compiled-in default for this option\nval\nThe value of the option if set\nlabel\nThe label of the option for display\ndisptype\nIndicator for how to display the option (see ConninfoDisplay)\ndispsize\nThe size of field to provide for entry of the option value (not used here)\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.conninfo",
    "page": "API",
    "title": "LibPQ.conninfo",
    "category": "function",
    "text": "conninfo(jl_conn::Connection) -> Vector{ConnectionOption}\n\nGet all connection options for a connection.\n\n\n\n\n\nconninfo(str::AbstractString) -> Vector{ConnectionOption}\n\nParse connection options from a connection string (either a URI or key-value pairs).\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.ConninfoDisplay",
    "page": "API",
    "title": "LibPQ.ConninfoDisplay",
    "category": "type",
    "text": "Indicator for how to display a PostgreSQL connection option (PQconninfoOption).\n\nPossible values are:\n\nNormal (libpq: \"\"): display as is\nPassword (libpq: \"*\"): hide the value of this field\nDebug (libpq: \"D\"): don\'t show by default\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Base.parse-Tuple{Type{LibPQ.ConninfoDisplay},AbstractString}",
    "page": "API",
    "title": "Base.parse",
    "category": "method",
    "text": "parse(::Type{ConninfoDisplay}, str::AbstractString) -> ConninfoDisplay\n\nParse a ConninfoDisplay from a string. See ConninfoDisplay.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Connection-Info-1",
    "page": "API",
    "title": "Connection Info",
    "category": "section",
    "text": "LibPQ.ConnectionOption\nLibPQ.conninfo\nLibPQ.ConninfoDisplay\nBase.parse(::Type{LibPQ.ConninfoDisplay}, ::AbstractString)"
},

{
    "location": "pages/api.html#LibPQ.handle_result",
    "page": "API",
    "title": "LibPQ.handle_result",
    "category": "function",
    "text": "handle_result(jl_result::Result; throw_error::Bool=true) -> Result\n\nCheck status and handle errors for newly-created result objects.\n\nIf throw_error is true, throw an error and clear the result if the query results in a fatal error or unreadable response. Otherwise a warning is shown.\n\nAlso print an info message about the result.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.column_name",
    "page": "API",
    "title": "LibPQ.column_name",
    "category": "function",
    "text": "column_name(jl_result::Result, column_number::Integer) -> String\n\nReturn the name of the column at index column_number (1-based).\n\n\n\n\n\ncolumn_name(stmt::Statement, column_number::Integer) -> String\n\nReturn the name of the column at index column_number (1-based) that would be returned by executing the prepared statement.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.column_names",
    "page": "API",
    "title": "LibPQ.column_names",
    "category": "function",
    "text": "column_names(jl_result::Result) -> Vector{String}\n\nReturn the names of all the columns in the query result.\n\n\n\n\n\ncolumn_names(stmt::Statement) -> Vector{String}\n\nReturn the names of all the columns in the query result that would be returned by executing the prepared statement.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.column_number",
    "page": "API",
    "title": "LibPQ.column_number",
    "category": "function",
    "text": "column_number(jl_result::Result, column_name::Union{AbstractString, Symbol}) -> Int\n\nReturn the index (1-based) of the column named column_name.\n\n\n\n\n\ncolumn_number(jl_result::Result, column_idx::Integer) -> Int\n\nReturn the index of the column if it is valid, or error.\n\n\n\n\n\ncolumn_number(stmt::Statement, column_name::AbstractString) -> Int\n\nReturn the index (1-based) of the column named column_name that would be returned by executing the prepared statement.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.column_oids",
    "page": "API",
    "title": "LibPQ.column_oids",
    "category": "function",
    "text": "column_oids(jl_result::Result) -> Vector{LibPQ.Oid}\n\nReturn the PostgreSQL oids for each column in the result.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.column_types",
    "page": "API",
    "title": "LibPQ.column_types",
    "category": "function",
    "text": "column_types(jl_result::Result) -> Vector{Type}\n\nReturn the corresponding Julia types for each column in the result.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.num_params-Tuple{LibPQ.Result}",
    "page": "API",
    "title": "LibPQ.num_params",
    "category": "method",
    "text": "num_params(jl_result::Result) -> Int\n\nReturn the number of parameters in a prepared statement. If this result did not come from the description of a prepared statement, return 0.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.error_message-Tuple{LibPQ.Result}",
    "page": "API",
    "title": "LibPQ.error_message",
    "category": "method",
    "text": "error_message(jl_result::Result) -> String\n\nReturn the error message associated with the result, or an empty string if there was no error. Includes a trailing newline.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Results-and-Statements-1",
    "page": "API",
    "title": "Results and Statements",
    "category": "section",
    "text": "LibPQ.handle_result\nLibPQ.column_name\nLibPQ.column_names\nLibPQ.column_number\nLibPQ.column_oids\nLibPQ.column_types\nLibPQ.num_params(::LibPQ.Result)\nLibPQ.error_message(::LibPQ.Result)"
},

{
    "location": "pages/api.html#LibPQ.oid",
    "page": "API",
    "title": "LibPQ.oid",
    "category": "function",
    "text": "oid(typ::Union{Symbol, String, Integer}) -> LibPQ.Oid\n\nConvert a PostgreSQL type from an AbstractString or Symbol representation to its oid representation. Integers are converted directly to LibPQ.Oids.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.PQChar",
    "page": "API",
    "title": "LibPQ.PQChar",
    "category": "type",
    "text": "primitive type PQChar 8\n\nA one-byte character type for correspondence with PostgreSQL\'s one-byte \"char\" type.\n\nFields:\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.PQ_SYSTEM_TYPES",
    "page": "API",
    "title": "LibPQ.PQ_SYSTEM_TYPES",
    "category": "constant",
    "text": "const PQ_SYSTEM_TYPES::Dict{Symbol, Oid}\n\nInternal mapping of PostgreSQL\'s default types from PostgreSQL internal name to Oid. The names may not correspond well to the common names, e.g., \"char(n)\" is :bpchar. This dictionary is generated with the deps/system_type_map.jl script and contains only PostgreSQL\'s system-defined types. It is expected (but might not be guaranteed) that these are the same across versions and installations.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.PQTypeMap",
    "page": "API",
    "title": "LibPQ.PQTypeMap",
    "category": "type",
    "text": "struct PQTypeMap <: AbstractDict{UInt32,Type}\n\nA mapping from PostgreSQL Oid to Julia type.\n\nFields:\n\ntype_map\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Base.getindex-Tuple{LibPQ.PQTypeMap,Any}",
    "page": "API",
    "title": "Base.getindex",
    "category": "method",
    "text": "Base.getindex(tmap::PQTypeMap, typ) -> Type\n\nGet the Julia type corresponding to the given PostgreSQL type (any type accepted by oid) according to tmap.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Base.setindex!-Tuple{LibPQ.PQTypeMap,Type,Any}",
    "page": "API",
    "title": "Base.setindex!",
    "category": "method",
    "text": "Base.setindex!(tmap::PQTypeMap, val::Type, typ)\n\nSet the Julia type corresponding to the given PostgreSQL type (any type accepted by oid) in tmap.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ._DEFAULT_TYPE_MAP",
    "page": "API",
    "title": "LibPQ._DEFAULT_TYPE_MAP",
    "category": "constant",
    "text": "const _DEFAULT_TYPE_MAP::PQTypeMap\n\nThe PQTypeMap containing the default type mappings for LibPQ.jl. This should not be mutated; LibPQ-level type mappings can be added to LIBPQ_TYPE_MAP.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.LIBPQ_TYPE_MAP",
    "page": "API",
    "title": "LibPQ.LIBPQ_TYPE_MAP",
    "category": "constant",
    "text": "const LIBPQ_TYPE_MAP::PQTypeMap\n\nThe PQTypeMap containing LibPQ-level type mappings for LibPQ.jl. Adding type mappings to this constant will override the default type mappings for all code using LibPQ.jl.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.PQConversions",
    "page": "API",
    "title": "LibPQ.PQConversions",
    "category": "type",
    "text": "struct PQConversions <: AbstractDict{Tuple{UInt32,Type},Union{Function, Type}}\n\nA mapping from Oid and Julia type pairs to the function for converting a PostgreSQL value with said Oid to said Julia type.\n\nFields:\n\nfunc_map\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Base.getindex-Tuple{LibPQ.PQConversions,Tuple{Any,Type}}",
    "page": "API",
    "title": "Base.getindex",
    "category": "method",
    "text": "Base.getindex(cmap::PQConversions, oid_typ::Tuple{Any, Type}) -> Base.Callable\n\nGet the function according to cmap for converting a PostgreSQL value of some PostgreSQL type (any type accepted by oid) to some Julia type.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Base.setindex!-Tuple{LibPQ.PQConversions,Union{Function, Type},Tuple{Any,Type}}",
    "page": "API",
    "title": "Base.setindex!",
    "category": "method",
    "text": "Base.setindex!(cmap::PQConversions, val::Base.Callable, oid_typ::Tuple{Any, Type})\n\nSet the function in cmap for converting a PostgreSQL value of some PostgreSQL type (any type accepted by oid) to some Julia type.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ._DEFAULT_CONVERSIONS",
    "page": "API",
    "title": "LibPQ._DEFAULT_CONVERSIONS",
    "category": "constant",
    "text": "const _DEFAULT_CONVERSIONS::PQConversions\n\nThe PQConversions containing the default conversion functions for LibPQ.jl. This should not be mutated; LibPQ-level conversion functions can be added to LIBPQ_CONVERSIONS.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.LIBPQ_CONVERSIONS",
    "page": "API",
    "title": "LibPQ.LIBPQ_CONVERSIONS",
    "category": "constant",
    "text": "const LIBPQ_CONVERSIONS::PQConversions\n\nThe PQConversions containing LibPQ-level conversion functions for LibPQ.jl. Adding conversions to this constant will override the default conversions for all code using LibPQ.jl.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ._FALLBACK_CONVERSION",
    "page": "API",
    "title": "LibPQ._FALLBACK_CONVERSION",
    "category": "constant",
    "text": "A fallback conversion mapping (like PQConversions which holds a single function for converting PostgreSQL data of a given Oid to a given Julia type, using the parse function.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Type-Conversions-1",
    "page": "API",
    "title": "Type Conversions",
    "category": "section",
    "text": "LibPQ.oid\nLibPQ.PQChar\nLibPQ.PQ_SYSTEM_TYPES\nLibPQ.PQTypeMap\nBase.getindex(::LibPQ.PQTypeMap, typ)\nBase.setindex!(::LibPQ.PQTypeMap, ::Type, typ)\nLibPQ._DEFAULT_TYPE_MAP\nLibPQ.LIBPQ_TYPE_MAP\nLibPQ.PQConversions\nBase.getindex(::LibPQ.PQConversions, oid_typ::Tuple{Any, Type})\nBase.setindex!(::LibPQ.PQConversions, ::Base.Callable, oid_typ::Tuple{Any, Type})\nLibPQ._DEFAULT_CONVERSIONS\nLibPQ.LIBPQ_CONVERSIONS\nLibPQ._FALLBACK_CONVERSION"
},

{
    "location": "pages/api.html#LibPQ.PQValue",
    "page": "API",
    "title": "LibPQ.PQValue",
    "category": "type",
    "text": "struct PQValue{OID}\n\nA wrapper for one value in a PostgreSQL result.\n\nFields:\n\njl_result\nPostgreSQL result\nrow\nRow index of the result (0-indexed)\ncol\nColumn index of the result (0-indexed)\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.data_pointer",
    "page": "API",
    "title": "LibPQ.data_pointer",
    "category": "function",
    "text": "data_pointer(pqv::PQValue) -> Ptr{UInt8}\n\nGet a raw pointer to the data for one value in a PostgreSQL result. This data will be freed by libpq when the result is cleared, and should only be used temporarily.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.num_bytes",
    "page": "API",
    "title": "LibPQ.num_bytes",
    "category": "function",
    "text": "num_bytes(pqv::PQValue) -> Cint\n\nThe length in bytes of the PQValue\'s corresponding data. LibPQ.jl currently always uses text format, so this is equivalent to C\'s strlen.\n\nSee also: data_pointer\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Base.unsafe_string-Tuple{LibPQ.PQValue}",
    "page": "API",
    "title": "Base.unsafe_string",
    "category": "method",
    "text": "unsafe_string(pqv::PQValue) -> String\n\nConstruct a String from a PQValue by copying the data.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.string_view",
    "page": "API",
    "title": "LibPQ.string_view",
    "category": "function",
    "text": "string_view(pqv::PQValue) -> String\n\nWrap a PQValue\'s underlying data in a String. This function uses data_pointer and num_bytes and does not copy.\n\nnote: Note\nThe underlying data will be freed by libpq when the result is cleared, and should only be used temporarily.\n\nSee also: bytes_view\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.bytes_view",
    "page": "API",
    "title": "LibPQ.bytes_view",
    "category": "function",
    "text": "bytes_view(pqv::PQValue) -> Vector{UInt8}\n\nWrap a PQValue\'s underlying data in a vector of bytes. This function uses data_pointer and num_bytes and does not copy.\n\nThis function differs from string_view as it keeps the   byte at the end. PQValue parsing functions should use bytes_view when the data returned by PostgreSQL is not in UTF-8.\n\nnote: Note\nThe underlying data will be freed by libpq when the result is cleared, and should only be used temporarily.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Base.parse-Tuple{Type{Any},LibPQ.PQValue}",
    "page": "API",
    "title": "Base.parse",
    "category": "method",
    "text": "parse(::Type{T}, pqv::PQValue) -> T\n\nParse a value of type T from a PQValue. By default, this uses any existing parse method for parsing a value of type T from a String.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Parsing-1",
    "page": "API",
    "title": "Parsing",
    "category": "section",
    "text": "LibPQ.PQValue\nLibPQ.data_pointer\nLibPQ.num_bytes\nBase.unsafe_string(::LibPQ.PQValue)\nLibPQ.string_view\nLibPQ.bytes_view\nBase.parse(::Type{Any}, pqv::LibPQ.PQValue)"
},

{
    "location": "pages/api.html#LibPQ.@pqv_str",
    "page": "API",
    "title": "LibPQ.@pqv_str",
    "category": "macro",
    "text": "@pqv_str -> VersionNumber\n\nParse a PostgreSQL version.\n\nnote: Note\nAs of version 10.0, PostgreSQL moved from a three-part version number (where the first two parts represent the major version and the third represents the minor version) to a two-part major-minor version number. In LibPQ.jl, we represent this using the first two VersionNumber components as the major version and the third as the minor version.Examplesjulia> using LibPQ: @pqv_str\n\njulia> pqv\"10.1\" == v\"10.0.1\"\ntrue\n\njulia> pqv\"9.2.5\" == v\"9.2.5\"\ntrue\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.string_parameters",
    "page": "API",
    "title": "LibPQ.string_parameters",
    "category": "function",
    "text": "string_parameters(parameters::AbstractVector) -> Vector{Union{String, Missing}}\n\nConvert parameters to strings which can be passed to libpq, propagating missing.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.parameter_pointers",
    "page": "API",
    "title": "LibPQ.parameter_pointers",
    "category": "function",
    "text": "parameter_pointers(parameters::AbstractVector{<:Parameter}) -> Vector{Ptr{UInt8}}\n\nGiven a vector of parameters, returns a vector of pointers to either the string bytes in the original or C_NULL if the element is missing.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#LibPQ.unsafe_string_or_null",
    "page": "API",
    "title": "LibPQ.unsafe_string_or_null",
    "category": "function",
    "text": "unsafe_string_or_null(ptr::Cstring) -> Union{String, Missing}\n\nConvert a Cstring to a Union{String, Missing}, returning missing if the pointer is C_NULL.\n\n\n\n\n\n"
},

{
    "location": "pages/api.html#Miscellaneous-1",
    "page": "API",
    "title": "Miscellaneous",
    "category": "section",
    "text": "LibPQ.@pqv_str\nLibPQ.string_parameters\nLibPQ.parameter_pointers\nLibPQ.unsafe_string_or_null"
},

]}
