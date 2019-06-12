####################################### BEGIN COMMON #######################################

# Automatically generated using Clang.jl wrap_c, version 0.0.0

# Translated from the libpq headers which are under the following copyright:
### PostgreSQL is Copyright © 1996-2017 by the PostgreSQL Global Development Group.
###
### Postgres95 is Copyright © 1994-5 by the Regents of the University of California.
###
### Permission to use, copy, modify, and distribute this software and its documentation for
### any purpose, without fee, and without a written agreement is hereby granted, provided
### that the above copyright notice and this paragraph and the following two paragraphs
### appear in all copies.
###
### IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR DIRECT,
### INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING LOST PROFITS, ARISING
### OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
### CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
###
### THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT
### LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
### PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON AN “AS-IS” BASIS, AND THE UNIVERSITY OF
### CALIFORNIA HAS NO OBLIGATIONS TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
### MODIFICATIONS.

const OBJC_NEW_PROPERTIES = 1

const NULL = C_NULL
const RENAME_SECLUDE = 0x00000001
const RENAME_SWAP = 0x00000002
const RENAME_EXCL = 0x00000004
const BUFSIZ = 1024
const EOF = -1
const FOPEN_MAX = 20
const FILENAME_MAX = 1024
const P_tmpdir = "/var/tmp/"
const L_tmpnam = 1024
const TMP_MAX = 308915776
const SEEK_SET = 0
const SEEK_CUR = 1
const SEEK_END = 2
const L_ctermid = 1024

# Skipping MacroDefinition: PG_INT64_TYPE long int
# Skipping MacroDefinition: InvalidOid ( ( Oid ) 0 )

const PG_DIAG_SEVERITY = 'S'
const PG_DIAG_SEVERITY_NONLOCALIZED = 'V'
const PG_DIAG_SQLSTATE = 'C'
const PG_DIAG_MESSAGE_PRIMARY = 'M'
const PG_DIAG_MESSAGE_DETAIL = 'D'
const PG_DIAG_MESSAGE_HINT = 'H'
const PG_DIAG_STATEMENT_POSITION = 'P'
const PG_DIAG_INTERNAL_POSITION = 'p'
const PG_DIAG_INTERNAL_QUERY = 'q'
const PG_DIAG_CONTEXT = 'W'
const PG_DIAG_SCHEMA_NAME = 's'
const PG_DIAG_TABLE_NAME = 't'
const PG_DIAG_COLUMN_NAME = 'c'
const PG_DIAG_DATATYPE_NAME = 'd'
const PG_DIAG_CONSTRAINT_NAME = 'n'
const PG_DIAG_SOURCE_FILE = 'F'
const PG_DIAG_SOURCE_LINE = 'L'
const PG_DIAG_SOURCE_FUNCTION = 'R'
const PG_COPYRES_ATTRS = 0x01
const PG_COPYRES_TUPLES = 0x02
const PG_COPYRES_EVENTS = 0x04
const PG_COPYRES_NOTICEHOOKS = 0x08

function PQsetdb(M_PGHOST, M_PGPORT, M_PGOPT, M_PGTTY, M_DBNAME)
    PQsetdbLogin(M_PGHOST, M_PGPORT, M_PGOPT, M_PGTTY, M_DBNAME, C_NULL, C_NULL)
end
PQfreeNotify(ptr) = PQfreemem(ptr)

const PQnoPasswordSupplied = "fe_sendauth: no password supplied\n"

mutable struct _opaque_pthread_attr_t
    __sig::Clong
    __opaque::NTuple{56, UInt8}
end

mutable struct _opaque_pthread_cond_t
    __sig::Clong
    __opaque::NTuple{40, UInt8}
end

mutable struct _opaque_pthread_condattr_t
    __sig::Clong
    __opaque::NTuple{8, UInt8}
end

mutable struct _opaque_pthread_mutex_t
    __sig::Clong
    __opaque::NTuple{56, UInt8}
end

mutable struct _opaque_pthread_mutexattr_t
    __sig::Clong
    __opaque::NTuple{8, UInt8}
end

mutable struct _opaque_pthread_once_t
    __sig::Clong
    __opaque::NTuple{8, UInt8}
end

mutable struct _opaque_pthread_rwlock_t
    __sig::Clong
    __opaque::NTuple{192, UInt8}
end

mutable struct _opaque_pthread_rwlockattr_t
    __sig::Clong
    __opaque::NTuple{16, UInt8}
end

mutable struct _opaque_pthread_t
    __sig::Clong
    __cleanup_stack::Ptr{Cvoid}
    __opaque::NTuple{8176, UInt8}
end

# monstly generated, some I followed Apple's _types.h to resolve
const int8_t = UInt8
const int16_t = Int16
const int32_t = Cint
const int64_t = Clonglong
const u_int8_t = Cuchar
const u_int16_t = UInt16
const u_int32_t = UInt32
const u_int64_t = Culonglong
const register_t = Int64
const intptr_t = Clong
const uintptr_t = Culong
const user_addr_t = u_int64_t
const user_size_t = u_int64_t
const user_ssize_t = Int64
const user_long_t = Int64
const user_ulong_t = u_int64_t
const user_time_t = Int64
const user_off_t = Int64
const syscall_arg_t = u_int64_t
const va_list = Ptr{Cvoid}
const size_t = Culong
const fpos_t = int64_t
const FILE = Cvoid
const off_t = int64_t
const ssize_t = Clong
const Oid = UInt32
const pg_int64 = Clong

const OID_MAX = typemax(Oid)
InvalidOid() = Oid(0)

@enum(ConnStatusType::Cuint,
    CONNECTION_OK,
    CONNECTION_BAD,
    CONNECTION_STARTED,
    CONNECTION_MADE,
    CONNECTION_AWAITING_RESPONSE,
    CONNECTION_AUTH_OK,
    CONNECTION_SETENV,
    CONNECTION_SSL_STARTUP,
    CONNECTION_NEEDED,
)

@enum(PostgresPollingStatusType::Cuint,
    PGRES_POLLING_FAILED,
    PGRES_POLLING_READING,
    PGRES_POLLING_WRITING,
    PGRES_POLLING_OK,
    PGRES_POLLING_ACTIVE,
)

@enum(ExecStatusType::Cuint,
    PGRES_EMPTY_QUERY,
    PGRES_COMMAND_OK,
    PGRES_TUPLES_OK,
    PGRES_COPY_OUT,
    PGRES_COPY_IN,
    PGRES_BAD_RESPONSE,
    PGRES_NONFATAL_ERROR,
    PGRES_FATAL_ERROR,
    PGRES_COPY_BOTH,
    PGRES_SINGLE_TUPLE,
)

@enum(PGTransactionStatusType::Cuint,
    PQTRANS_IDLE,
    PQTRANS_ACTIVE,
    PQTRANS_INTRANS,
    PQTRANS_INERROR,
    PQTRANS_UNKNOWN,
)

@enum(PGVerbosity::Cuint,
    PQERRORS_TERSE,
    PQERRORS_DEFAULT,
    PQERRORS_VERBOSE,
)

@enum(PGContextVisibility::Cuint,
    PQSHOW_CONTEXT_NEVER,
    PQSHOW_CONTEXT_ERRORS,
    PQSHOW_CONTEXT_ALWAYS,
)

@enum(PGPing::Cuint,
    PQPING_OK,
    PQPING_REJECT,
    PQPING_NO_RESPONSE,
    PQPING_NO_ATTEMPT,
)

const PGconn = Cvoid

const PGresult = Cvoid

mutable struct pg_cancel
end

const PGcancel = Cvoid

mutable struct pgNotify
    relname::Cstring
    be_pid::Cint
    extra::Cstring
    next::Ptr{Cvoid}
end

const PGnotify = Cvoid
const PQnoticeReceiver = Ptr{Cvoid}
const PQnoticeProcessor = Ptr{Cvoid}
const pqbool = UInt8

mutable struct _PQprintOpt
    header::pqbool
    align::pqbool
    standard::pqbool
    html3::pqbool
    expanded::pqbool
    pager::pqbool
    fieldSep::Cstring
    tableOpt::Cstring
    caption::Cstring
    fieldName::Ptr{Cstring}
end

const PQprintOpt = Cvoid

struct PQconninfoOption
    keyword::Cstring
    envvar::Cstring
    compiled::Cstring
    val::Cstring
    label::Cstring
    dispchar::Cstring
    dispsize::Cint
end

const PQArgBlock = Cvoid

mutable struct pgresAttDesc
    name::Cstring
    tableid::Oid
    columnid::Cint
    format::Cint
    typid::Oid
    typlen::Cint
    atttypmod::Cint
end

const PGresAttDesc = Cvoid
const pgthreadlock_t = Ptr{Cvoid}

####################################### END COMMON #########################################

# Julia wrapper for header: /usr/local/opt/libpq/include/libpq-fe.h
# Automatically generated using Clang.jl wrap_c, version 0.0.0

function PQconnectStart(conninfo)
    ccall((:PQconnectStart, LIBPQ_HANDLE), Ptr{PGconn}, (Cstring,), conninfo)
end

function PQconnectStartParams(keywords, values, expand_dbname::Cint)
    ccall((:PQconnectStartParams, LIBPQ_HANDLE), Ptr{PGconn}, (Ptr{Ptr{UInt8}}, Ptr{Ptr{UInt8}}, Cint), keywords, values, expand_dbname)
end

function PQconnectPoll(conn)
    ccall((:PQconnectPoll, LIBPQ_HANDLE), PostgresPollingStatusType, (Ptr{PGconn},), conn)
end

function PQconnectdb(conninfo)
    ccall((:PQconnectdb, LIBPQ_HANDLE), Ptr{PGconn}, (Cstring,), conninfo)
end

function PQconnectdbParams(keywords, values, expand_dbname)
    ccall((:PQconnectdbParams, LIBPQ_HANDLE), Ptr{PGconn}, (Ptr{Ptr{UInt8}}, Ptr{Ptr{UInt8}}, Cint), keywords, values, expand_dbname)
end

function PQsetdbLogin(pghost, pgport, pgoptions, pgtty, dbName, login, pwd)
    ccall((:PQsetdbLogin, LIBPQ_HANDLE), Ptr{PGconn}, (Cstring, Cstring, Cstring, Cstring, Cstring, Cstring, Cstring), pghost, pgport, pgoptions, pgtty, dbName, login, pwd)
end

function PQfinish(conn)
    ccall((:PQfinish, LIBPQ_HANDLE), Cvoid, (Ptr{PGconn},), conn)
end

function PQconndefaults()
    ccall((:PQconndefaults, LIBPQ_HANDLE), Ptr{PQconninfoOption}, ())
end

function PQconninfoParse(conninfo, errmsg)
    ccall((:PQconninfoParse, LIBPQ_HANDLE), Ptr{PQconninfoOption}, (Cstring, Ptr{Ptr{UInt8}}), conninfo, errmsg)
end

function PQconninfo(conn)
    ccall((:PQconninfo, LIBPQ_HANDLE), Ptr{PQconninfoOption}, (Ptr{PGconn},), conn)
end

function PQconninfoFree(connOptions)
    ccall((:PQconninfoFree, LIBPQ_HANDLE), Cvoid, (Ptr{PQconninfoOption},), connOptions)
end

function PQresetStart(conn)
    ccall((:PQresetStart, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQresetPoll(conn)
    ccall((:PQresetPoll, LIBPQ_HANDLE), PostgresPollingStatusType, (Ptr{PGconn},), conn)
end

function PQreset(conn)
    ccall((:PQreset, LIBPQ_HANDLE), Cvoid, (Ptr{PGconn},), conn)
end

function PQgetCancel(conn)
    ccall((:PQgetCancel, LIBPQ_HANDLE), Ptr{PGcancel}, (Ptr{PGconn},), conn)
end

function PQfreeCancel(cancel)
    ccall((:PQfreeCancel, LIBPQ_HANDLE), Cvoid, (Ptr{PGcancel},), cancel)
end

function PQcancel(cancel, errbuf, errbufsize)
    ccall((:PQcancel, LIBPQ_HANDLE), Cint, (Ptr{PGcancel}, Cstring, Cint), cancel, errbuf, errbufsize)
end

function PQrequestCancel(conn)
    ccall((:PQrequestCancel, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQdb(conn)
    ccall((:PQdb, LIBPQ_HANDLE), Cstring, (Ptr{PGconn},), conn)
end

function PQuser(conn)
    ccall((:PQuser, LIBPQ_HANDLE), Cstring, (Ptr{PGconn},), conn)
end

function PQpass(conn)
    ccall((:PQpass, LIBPQ_HANDLE), Cstring, (Ptr{PGconn},), conn)
end

function PQhost(conn)
    ccall((:PQhost, LIBPQ_HANDLE), Cstring, (Ptr{PGconn},), conn)
end

function PQport(conn)
    ccall((:PQport, LIBPQ_HANDLE), Cstring, (Ptr{PGconn},), conn)
end

function PQtty(conn)
    ccall((:PQtty, LIBPQ_HANDLE), Cstring, (Ptr{PGconn},), conn)
end

function PQoptions(conn)
    ccall((:PQoptions, LIBPQ_HANDLE), Cstring, (Ptr{PGconn},), conn)
end

function PQstatus(conn)
    ccall((:PQstatus, LIBPQ_HANDLE), ConnStatusType, (Ptr{PGconn},), conn)
end

function PQtransactionStatus(conn)
    ccall((:PQtransactionStatus, LIBPQ_HANDLE), PGTransactionStatusType, (Ptr{PGconn},), conn)
end

function PQparameterStatus(conn, paramName)
    ccall((:PQparameterStatus, LIBPQ_HANDLE), Cstring, (Ptr{PGconn}, Cstring), conn, paramName)
end

function PQprotocolVersion(conn)
    ccall((:PQprotocolVersion, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQserverVersion(conn)
    ccall((:PQserverVersion, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQerrorMessage(conn)
    ccall((:PQerrorMessage, LIBPQ_HANDLE), Cstring, (Ptr{PGconn},), conn)
end

function PQsocket(conn)
    ccall((:PQsocket, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQbackendPID(conn)
    ccall((:PQbackendPID, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQconnectionNeedsPassword(conn)
    ccall((:PQconnectionNeedsPassword, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQconnectionUsedPassword(conn)
    ccall((:PQconnectionUsedPassword, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQclientEncoding(conn)
    ccall((:PQclientEncoding, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQsetClientEncoding(conn, encoding)
    ccall((:PQsetClientEncoding, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cstring), conn, encoding)
end

function PQsslInUse(conn)
    ccall((:PQsslInUse, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQsslStruct(conn, struct_name)
    ccall((:PQsslStruct, LIBPQ_HANDLE), Ptr{Cvoid}, (Ptr{PGconn}, Cstring), conn, struct_name)
end

function PQsslAttribute(conn, attribute_name)
    ccall((:PQsslAttribute, LIBPQ_HANDLE), Cstring, (Ptr{PGconn}, Cstring), conn, attribute_name)
end

function PQsslAttributeNames(conn)
    ccall((:PQsslAttributeNames, LIBPQ_HANDLE), Ptr{Cstring}, (Ptr{PGconn},), conn)
end

function PQgetssl(conn)
    ccall((:PQgetssl, LIBPQ_HANDLE), Ptr{Cvoid}, (Ptr{PGconn},), conn)
end

function PQinitSSL(do_init::Cint)
    ccall((:PQinitSSL, LIBPQ_HANDLE), Cvoid, (Cint,), do_init)
end

function PQinitOpenSSL(do_ssl::Cint, do_crypto::Cint)
    ccall((:PQinitOpenSSL, LIBPQ_HANDLE), Cvoid, (Cint, Cint), do_ssl, do_crypto)
end

function PQsetErrorVerbosity(conn, verbosity::PGVerbosity)
    ccall((:PQsetErrorVerbosity, LIBPQ_HANDLE), PGVerbosity, (Ptr{PGconn}, PGVerbosity), conn, verbosity)
end

function PQsetErrorContextVisibility(conn, show_context::PGContextVisibility)
    ccall((:PQsetErrorContextVisibility, LIBPQ_HANDLE), PGContextVisibility, (Ptr{PGconn}, PGContextVisibility), conn, show_context)
end

function PQtrace(conn, debug_port)
    ccall((:PQtrace, LIBPQ_HANDLE), Cvoid, (Ptr{PGconn}, Ptr{FILE}), conn, debug_port)
end

function PQuntrace(conn)
    ccall((:PQuntrace, LIBPQ_HANDLE), Cvoid, (Ptr{PGconn},), conn)
end

function PQsetNoticeReceiver(conn, proc::PQnoticeReceiver, arg)
    ccall((:PQsetNoticeReceiver, LIBPQ_HANDLE), PQnoticeReceiver, (Ptr{PGconn}, PQnoticeReceiver, Ptr{Cvoid}), conn, proc, arg)
end

function PQsetNoticeProcessor(conn, proc::PQnoticeProcessor, arg)
    ccall((:PQsetNoticeProcessor, LIBPQ_HANDLE), PQnoticeProcessor, (Ptr{PGconn}, PQnoticeProcessor, Ptr{Cvoid}), conn, proc, arg)
end

function PQregisterThreadLock(newhandler::pgthreadlock_t)
    ccall((:PQregisterThreadLock, LIBPQ_HANDLE), pgthreadlock_t, (pgthreadlock_t,), newhandler)
end

function PQexec(conn, query)
    ccall((:PQexec, LIBPQ_HANDLE), Ptr{PGresult}, (Ptr{PGconn}, Cstring), conn, query)
end

function PQexecParams(conn, command, nParams, paramTypes, paramValues, paramLengths, paramFormats, resultFormat)
    ccall((:PQexecParams, LIBPQ_HANDLE), Ptr{PGresult}, (Ptr{PGconn}, Cstring, Cint, Ptr{Oid}, Ptr{Ptr{UInt8}}, Ptr{Cint}, Ptr{Cint}, Cint), conn, command, nParams, paramTypes, paramValues, paramLengths, paramFormats, resultFormat)
end

function PQprepare(conn, stmtName, query, nParams, paramTypes)
    ccall((:PQprepare, LIBPQ_HANDLE), Ptr{PGresult}, (Ptr{PGconn}, Cstring, Cstring, Cint, Ptr{Oid}), conn, stmtName, query, nParams, paramTypes)
end

function PQexecPrepared(conn, stmtName, nParams, paramValues, paramLengths, paramFormats, resultFormat)
    ccall((:PQexecPrepared, LIBPQ_HANDLE), Ptr{PGresult}, (Ptr{PGconn}, Cstring, Cint, Ptr{Ptr{UInt8}}, Ptr{Cint}, Ptr{Cint}, Cint), conn, stmtName, nParams, paramValues, paramLengths, paramFormats, resultFormat)
end

function PQsendQuery(conn, query)
    ccall((:PQsendQuery, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cstring), conn, query)
end

function PQsendQueryParams(conn, command, nParams, paramTypes, paramValues, paramLengths, paramFormats, resultFormat)
    ccall((:PQsendQueryParams, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cstring, Cint, Ptr{Oid}, Ptr{Ptr{UInt8}}, Ptr{Cint}, Ptr{Cint}, Cint), conn, command, nParams, paramTypes, paramValues, paramLengths, paramFormats, resultFormat)
end

function PQsendPrepare(conn, stmtName, query, nParams, paramTypes)
    ccall((:PQsendPrepare, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cstring, Cstring, Cint, Ptr{Oid}), conn, stmtName, query, nParams, paramTypes)
end

function PQsendQueryPrepared(conn, stmtName, nParams, paramValues, paramLengths, paramFormats, resultFormat)
    ccall((:PQsendQueryPrepared, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cstring, Cint, Ptr{Ptr{UInt8}}, Ptr{Cint}, Ptr{Cint}, Cint), conn, stmtName, nParams, paramValues, paramLengths, paramFormats, resultFormat)
end

function PQsetSingleRowMode(conn)
    ccall((:PQsetSingleRowMode, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQgetResult(conn)
    ccall((:PQgetResult, LIBPQ_HANDLE), Ptr{PGresult}, (Ptr{PGconn},), conn)
end

function PQisBusy(conn)
    ccall((:PQisBusy, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQconsumeInput(conn)
    ccall((:PQconsumeInput, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQnotifies(conn)
    ccall((:PQnotifies, LIBPQ_HANDLE), Ptr{PGnotify}, (Ptr{PGconn},), conn)
end

function PQputCopyData(conn, buffer, nbytes)
    ccall((:PQputCopyData, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cstring, Cint), conn, buffer, nbytes)
end

function PQputCopyEnd(conn, errormsg)
    ccall((:PQputCopyEnd, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cstring), conn, errormsg)
end

function PQgetCopyData(conn, buffer, async::Cint)
    ccall((:PQgetCopyData, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Ptr{Cstring}, Cint), conn, buffer, async)
end

function PQgetline(conn, string, length::Cint)
    ccall((:PQgetline, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cstring, Cint), conn, string, length)
end

function PQputline(conn, string)
    ccall((:PQputline, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cstring), conn, string)
end

function PQgetlineAsync(conn, buffer, bufsize::Cint)
    ccall((:PQgetlineAsync, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cstring, Cint), conn, buffer, bufsize)
end

function PQputnbytes(conn, buffer, nbytes::Cint)
    ccall((:PQputnbytes, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cstring, Cint), conn, buffer, nbytes)
end

function PQendcopy(conn)
    ccall((:PQendcopy, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQsetnonblocking(conn, arg::Cint)
    ccall((:PQsetnonblocking, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cint), conn, arg)
end

function PQisnonblocking(conn)
    ccall((:PQisnonblocking, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQisthreadsafe()
    ccall((:PQisthreadsafe, LIBPQ_HANDLE), Cint, ())
end

function PQping(conninfo)
    ccall((:PQping, LIBPQ_HANDLE), PGPing, (Cstring,), conninfo)
end

function PQpingParams(keywords, values, expand_dbname::Cint)
    ccall((:PQpingParams, LIBPQ_HANDLE), PGPing, (Ptr{Ptr{UInt8}}, Ptr{Ptr{UInt8}}, Cint), keywords, values, expand_dbname)
end

function PQflush(conn)
    ccall((:PQflush, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQfn(conn, fnid::Cint, result_buf, result_len, result_is_int::Cint, args, nargs::Cint)
    ccall((:PQfn, LIBPQ_HANDLE), Ptr{PGresult}, (Ptr{PGconn}, Cint, Ptr{Cint}, Ptr{Cint}, Cint, Ptr{PQArgBlock}, Cint), conn, fnid, result_buf, result_len, result_is_int, args, nargs)
end

function PQresultStatus(res)
    ccall((:PQresultStatus, LIBPQ_HANDLE), ExecStatusType, (Ptr{PGresult},), res)
end

function PQresStatus(status::ExecStatusType)
    ccall((:PQresStatus, LIBPQ_HANDLE), Cstring, (ExecStatusType,), status)
end

function PQresultErrorMessage(res)
    ccall((:PQresultErrorMessage, LIBPQ_HANDLE), Cstring, (Ptr{PGresult},), res)
end

function PQresultVerboseErrorMessage(res, verbosity::PGVerbosity, show_context::PGContextVisibility)
    ccall((:PQresultVerboseErrorMessage, LIBPQ_HANDLE), Cstring, (Ptr{PGresult}, PGVerbosity, PGContextVisibility), res, verbosity, show_context)
end

function PQresultErrorField(res, fieldcode::Cint)
    ccall((:PQresultErrorField, LIBPQ_HANDLE), Cstring, (Ptr{PGresult}, Cint), res, fieldcode)
end

function PQntuples(res)
    ccall((:PQntuples, LIBPQ_HANDLE), Cint, (Ptr{PGresult},), res)
end

function PQnfields(res)
    ccall((:PQnfields, LIBPQ_HANDLE), Cint, (Ptr{PGresult},), res)
end

function PQbinaryTuples(res)
    ccall((:PQbinaryTuples, LIBPQ_HANDLE), Cint, (Ptr{PGresult},), res)
end

function PQfname(res, field_num)
    ccall((:PQfname, LIBPQ_HANDLE), Cstring, (Ptr{PGresult}, Cint), res, field_num)
end

function PQfnumber(res, field_name)
    ccall((:PQfnumber, LIBPQ_HANDLE), Cint, (Ptr{PGresult}, Cstring), res, field_name)
end

function PQftable(res, field_num)
    ccall((:PQftable, LIBPQ_HANDLE), Oid, (Ptr{PGresult}, Cint), res, field_num)
end

function PQftablecol(res, field_num)
    ccall((:PQftablecol, LIBPQ_HANDLE), Cint, (Ptr{PGresult}, Cint), res, field_num)
end

function PQfformat(res, field_num)
    ccall((:PQfformat, LIBPQ_HANDLE), Cint, (Ptr{PGresult}, Cint), res, field_num)
end

function PQftype(res, field_num)
    ccall((:PQftype, LIBPQ_HANDLE), Oid, (Ptr{PGresult}, Cint), res, field_num)
end

function PQfsize(res, field_num)
    ccall((:PQfsize, LIBPQ_HANDLE), Cint, (Ptr{PGresult}, Cint), res, field_num)
end

function PQfmod(res, field_num)
    ccall((:PQfmod, LIBPQ_HANDLE), Cint, (Ptr{PGresult}, Cint), res, field_num)
end

function PQcmdStatus(res)
    ccall((:PQcmdStatus, LIBPQ_HANDLE), Cstring, (Ptr{PGresult},), res)
end

function PQoidStatus(res)
    ccall((:PQoidStatus, LIBPQ_HANDLE), Cstring, (Ptr{PGresult},), res)
end

function PQoidValue(res)
    ccall((:PQoidValue, LIBPQ_HANDLE), Oid, (Ptr{PGresult},), res)
end

function PQcmdTuples(res)
    ccall((:PQcmdTuples, LIBPQ_HANDLE), Cstring, (Ptr{PGresult},), res)
end

function PQgetvalue(res, tup_num, field_num)
    ccall((:PQgetvalue, LIBPQ_HANDLE), Ptr{UInt8}, (Ptr{PGresult}, Cint, Cint), res, tup_num, field_num)
end

function PQgetlength(res, tup_num, field_num)
    ccall((:PQgetlength, LIBPQ_HANDLE), Cint, (Ptr{PGresult}, Cint, Cint), res, tup_num, field_num)
end

function PQgetisnull(res, tup_num, field_num)
    ccall((:PQgetisnull, LIBPQ_HANDLE), Cint, (Ptr{PGresult}, Cint, Cint), res, tup_num, field_num)
end

function PQnparams(res)
    ccall((:PQnparams, LIBPQ_HANDLE), Cint, (Ptr{PGresult},), res)
end

function PQparamtype(res, param_num)
    ccall((:PQparamtype, LIBPQ_HANDLE), Oid, (Ptr{PGresult}, Cint), res, param_num)
end

function PQdescribePrepared(conn, stmt)
    ccall((:PQdescribePrepared, LIBPQ_HANDLE), Ptr{PGresult}, (Ptr{PGconn}, Cstring), conn, stmt)
end

function PQdescribePortal(conn, portal)
    ccall((:PQdescribePortal, LIBPQ_HANDLE), Ptr{PGresult}, (Ptr{PGconn}, Cstring), conn, portal)
end

function PQsendDescribePrepared(conn, stmt)
    ccall((:PQsendDescribePrepared, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cstring), conn, stmt)
end

function PQsendDescribePortal(conn, portal)
    ccall((:PQsendDescribePortal, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cstring), conn, portal)
end

function PQclear(res)
    ccall((:PQclear, LIBPQ_HANDLE), Cvoid, (Ptr{PGresult},), res)
end

function PQfreemem(ptr)
    ccall((:PQfreemem, LIBPQ_HANDLE), Cvoid, (Ptr{Cvoid},), ptr)
end

function PQmakeEmptyPGresult(conn, status::ExecStatusType)
    ccall((:PQmakeEmptyPGresult, LIBPQ_HANDLE), Ptr{PGresult}, (Ptr{PGconn}, ExecStatusType), conn, status)
end

function PQcopyResult(src, flags::Cint)
    ccall((:PQcopyResult, LIBPQ_HANDLE), Ptr{PGresult}, (Ptr{PGresult}, Cint), src, flags)
end

function PQsetResultAttrs(res, numAttributes::Cint, attDescs)
    ccall((:PQsetResultAttrs, LIBPQ_HANDLE), Cint, (Ptr{PGresult}, Cint, Ptr{PGresAttDesc}), res, numAttributes, attDescs)
end

function PQresultAlloc(res, nBytes::Csize_t)
    ccall((:PQresultAlloc, LIBPQ_HANDLE), Ptr{Cvoid}, (Ptr{PGresult}, Csize_t), res, nBytes)
end

function PQsetvalue(res, tup_num::Cint, field_num::Cint, value, len::Cint)
    ccall((:PQsetvalue, LIBPQ_HANDLE), Cint, (Ptr{PGresult}, Cint, Cint, Cstring, Cint), res, tup_num, field_num, value, len)
end

function PQescapeStringConn(conn, to, from, length::Csize_t, error)
    ccall((:PQescapeStringConn, LIBPQ_HANDLE), Csize_t, (Ptr{PGconn}, Cstring, Cstring, Csize_t, Ptr{Cint}), conn, to, from, length, error)
end

function PQescapeLiteral(conn, str, len::Csize_t)
    ccall((:PQescapeLiteral, LIBPQ_HANDLE), Cstring, (Ptr{PGconn}, Cstring, Csize_t), conn, str, len)
end

function PQescapeIdentifier(conn, str, len::Csize_t)
    ccall((:PQescapeIdentifier, LIBPQ_HANDLE), Cstring, (Ptr{PGconn}, Cstring, Csize_t), conn, str, len)
end

function PQescapeByteaConn(conn, from, from_length::Csize_t, to_length)
    ccall((:PQescapeByteaConn, LIBPQ_HANDLE), Ptr{Cuchar}, (Ptr{PGconn}, Ptr{Cuchar}, Csize_t, Ptr{Csize_t}), conn, from, from_length, to_length)
end

function PQunescapeBytea(strtext, retbuflen::Ref{Csize_t})
    ccall((:PQunescapeBytea, LIBPQ_HANDLE), Ptr{Cuchar}, (Ptr{Cuchar}, Ref{Csize_t}), strtext, retbuflen)
end

function PQescapeString(to, from, length::Csize_t)
    ccall((:PQescapeString, LIBPQ_HANDLE), Csize_t, (Cstring, Cstring, Csize_t), to, from, length)
end

function PQescapeBytea(from, from_length::Csize_t, to_length)
    ccall((:PQescapeBytea, LIBPQ_HANDLE), Ptr{Cuchar}, (Ptr{Cuchar}, Csize_t, Ptr{Csize_t}), from, from_length, to_length)
end

function PQprint(fout, res, ps)
    ccall((:PQprint, LIBPQ_HANDLE), Cvoid, (Ptr{FILE}, Ptr{PGresult}, Ptr{PQprintOpt}), fout, res, ps)
end

function PQdisplayTuples(res, fp, fillAlign::Cint, fieldSep, printHeader::Cint, quiet::Cint)
    ccall((:PQdisplayTuples, LIBPQ_HANDLE), Cvoid, (Ptr{PGresult}, Ptr{FILE}, Cint, Cstring, Cint, Cint), res, fp, fillAlign, fieldSep, printHeader, quiet)
end

function PQprintTuples(res, fout, printAttName::Cint, terseOutput::Cint, width::Cint)
    ccall((:PQprintTuples, LIBPQ_HANDLE), Cvoid, (Ptr{PGresult}, Ptr{FILE}, Cint, Cint, Cint), res, fout, printAttName, terseOutput, width)
end

function lo_open(conn, lobjId::Oid, mode::Cint)
    ccall((:lo_open, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Oid, Cint), conn, lobjId, mode)
end

function lo_close(conn, fd::Cint)
    ccall((:lo_close, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cint), conn, fd)
end

function lo_read(conn, fd::Cint, buf, len::Csize_t)
    ccall((:lo_read, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cint, Cstring, Csize_t), conn, fd, buf, len)
end

function lo_write(conn, fd::Cint, buf, len::Csize_t)
    ccall((:lo_write, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cint, Cstring, Csize_t), conn, fd, buf, len)
end

function lo_lseek(conn, fd::Cint, offset::Cint, whence::Cint)
    ccall((:lo_lseek, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cint, Cint, Cint), conn, fd, offset, whence)
end

function lo_lseek64(conn, fd::Cint, offset::pg_int64, whence::Cint)
    ccall((:lo_lseek64, LIBPQ_HANDLE), pg_int64, (Ptr{PGconn}, Cint, pg_int64, Cint), conn, fd, offset, whence)
end

function lo_creat(conn, mode::Cint)
    ccall((:lo_creat, LIBPQ_HANDLE), Oid, (Ptr{PGconn}, Cint), conn, mode)
end

function lo_create(conn, lobjId::Oid)
    ccall((:lo_create, LIBPQ_HANDLE), Oid, (Ptr{PGconn}, Oid), conn, lobjId)
end

function lo_tell(conn, fd::Cint)
    ccall((:lo_tell, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cint), conn, fd)
end

function lo_tell64(conn, fd::Cint)
    ccall((:lo_tell64, LIBPQ_HANDLE), pg_int64, (Ptr{PGconn}, Cint), conn, fd)
end

function lo_truncate(conn, fd::Cint, len::Csize_t)
    ccall((:lo_truncate, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cint, Csize_t), conn, fd, len)
end

function lo_truncate64(conn, fd::Cint, len::pg_int64)
    ccall((:lo_truncate64, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cint, pg_int64), conn, fd, len)
end

function lo_unlink(conn, lobjId::Oid)
    ccall((:lo_unlink, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Oid), conn, lobjId)
end

function lo_import(conn, filename)
    ccall((:lo_import, LIBPQ_HANDLE), Oid, (Ptr{PGconn}, Cstring), conn, filename)
end

function lo_import_with_oid(conn, filename, lobjId::Oid)
    ccall((:lo_import_with_oid, LIBPQ_HANDLE), Oid, (Ptr{PGconn}, Cstring, Oid), conn, filename, lobjId)
end

function lo_export(conn, lobjId::Oid, filename)
    ccall((:lo_export, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Oid, Cstring), conn, lobjId, filename)
end

function PQlibVersion()
    ccall((:PQlibVersion, LIBPQ_HANDLE), Cint, ())
end

function PQmblen(s, encoding::Cint)
    ccall((:PQmblen, LIBPQ_HANDLE), Cint, (Cstring, Cint), s, encoding)
end

function PQdsplen(s, encoding::Cint)
    ccall((:PQdsplen, LIBPQ_HANDLE), Cint, (Cstring, Cint), s, encoding)
end

function PQenv2encoding()
    ccall((:PQenv2encoding, LIBPQ_HANDLE), Cint, ())
end

function PQencryptPassword(passwd, user)
    ccall((:PQencryptPassword, LIBPQ_HANDLE), Cstring, (Cstring, Cstring), passwd, user)
end

function pg_char_to_encoding(name)
    ccall((:pg_char_to_encoding, LIBPQ_HANDLE), Cint, (Cstring,), name)
end

function pg_encoding_to_char(encoding::Cint)
    ccall((:pg_encoding_to_char, LIBPQ_HANDLE), Cstring, (Cint,), encoding)
end

function pg_valid_server_encoding_id(encoding::Cint)
    ccall((:pg_valid_server_encoding_id, LIBPQ_HANDLE), Cint, (Cint,), encoding)
end
