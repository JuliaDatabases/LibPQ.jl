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
    return PQsetdbLogin(M_PGHOST, M_PGPORT, M_PGOPT, M_PGTTY, M_DBNAME, C_NULL, C_NULL)
end
PQfreeNotify(ptr) = PQfreemem(ptr)

const PQnoPasswordSupplied = "fe_sendauth: no password supplied\n"

mutable struct _opaque_pthread_attr_t
    __sig::Clong
    __opaque::NTuple{56,UInt8}
end

mutable struct _opaque_pthread_cond_t
    __sig::Clong
    __opaque::NTuple{40,UInt8}
end

mutable struct _opaque_pthread_condattr_t
    __sig::Clong
    __opaque::NTuple{8,UInt8}
end

mutable struct _opaque_pthread_mutex_t
    __sig::Clong
    __opaque::NTuple{56,UInt8}
end

mutable struct _opaque_pthread_mutexattr_t
    __sig::Clong
    __opaque::NTuple{8,UInt8}
end

mutable struct _opaque_pthread_once_t
    __sig::Clong
    __opaque::NTuple{8,UInt8}
end

mutable struct _opaque_pthread_rwlock_t
    __sig::Clong
    __opaque::NTuple{192,UInt8}
end

mutable struct _opaque_pthread_rwlockattr_t
    __sig::Clong
    __opaque::NTuple{16,UInt8}
end

mutable struct _opaque_pthread_t
    __sig::Clong
    __cleanup_stack::Ptr{Cvoid}
    __opaque::NTuple{8176,UInt8}
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

@enum(
    ConnStatusType::Cuint,
    CONNECTION_OK,
    CONNECTION_BAD,
    CONNECTION_STARTED,
    CONNECTION_MADE,
    CONNECTION_AWAITING_RESPONSE,
    CONNECTION_AUTH_OK,
    CONNECTION_SETENV,
    CONNECTION_SSL_STARTUP,
    CONNECTION_NEEDED,
    CONNECTION_CHECK_WRITABLE,
    CONNECTION_CONSUME,
    CONNECTION_GSS_STARTUP,
    CONNECTION_CHECK_TARGET,
)

@enum(
    PostgresPollingStatusType::Cuint,
    PGRES_POLLING_FAILED,
    PGRES_POLLING_READING,
    PGRES_POLLING_WRITING,
    PGRES_POLLING_OK,
    PGRES_POLLING_ACTIVE,
)

@enum(
    ExecStatusType::Cuint,
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

@enum(
    PGTransactionStatusType::Cuint,
    PQTRANS_IDLE,
    PQTRANS_ACTIVE,
    PQTRANS_INTRANS,
    PQTRANS_INERROR,
    PQTRANS_UNKNOWN,
)

@enum(PGVerbosity::Cuint, PQERRORS_TERSE, PQERRORS_DEFAULT, PQERRORS_VERBOSE,)

@enum(
    PGContextVisibility::Cuint,
    PQSHOW_CONTEXT_NEVER,
    PQSHOW_CONTEXT_ERRORS,
    PQSHOW_CONTEXT_ALWAYS,
)

@enum(PGPing::Cuint, PQPING_OK, PQPING_REJECT, PQPING_NO_RESPONSE, PQPING_NO_ATTEMPT,)

const PGconn = Cvoid

const PGresult = Cvoid

mutable struct pg_cancel end

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
    return ccall((:PQconnectStart, LIBPQ_HANDLE), Ptr{PGconn}, (Cstring,), conninfo)
end

function PQconnectStartParams(keywords, values, expand_dbname)
    return ccall(
        (:PQconnectStartParams, LIBPQ_HANDLE),
        Ptr{PGconn},
        (Ptr{Ptr{UInt8}}, Ptr{Ptr{UInt8}}, Cint),
        keywords,
        values,
        expand_dbname,
    )
end

function PQconnectPoll(conn)
    return ccall(
        (:PQconnectPoll, LIBPQ_HANDLE), PostgresPollingStatusType, (Ptr{PGconn},), conn
    )
end

function PQconnectdb(conninfo)
    return ccall((:PQconnectdb, LIBPQ_HANDLE), Ptr{PGconn}, (Cstring,), conninfo)
end

function PQconnectdbParams(keywords, values, expand_dbname)
    return ccall(
        (:PQconnectdbParams, LIBPQ_HANDLE),
        Ptr{PGconn},
        (Ptr{Ptr{UInt8}}, Ptr{Ptr{UInt8}}, Cint),
        keywords,
        values,
        expand_dbname,
    )
end

function PQsetdbLogin(pghost, pgport, pgoptions, pgtty, dbName, login, pwd)
    return ccall(
        (:PQsetdbLogin, LIBPQ_HANDLE),
        Ptr{PGconn},
        (Cstring, Cstring, Cstring, Cstring, Cstring, Cstring, Cstring),
        pghost,
        pgport,
        pgoptions,
        pgtty,
        dbName,
        login,
        pwd,
    )
end

function PQfinish(conn)
    return ccall((:PQfinish, LIBPQ_HANDLE), Cvoid, (Ptr{PGconn},), conn)
end

function PQconndefaults()
    return ccall((:PQconndefaults, LIBPQ_HANDLE), Ptr{PQconninfoOption}, ())
end

function PQconninfoParse(conninfo, errmsg)
    return ccall(
        (:PQconninfoParse, LIBPQ_HANDLE),
        Ptr{PQconninfoOption},
        (Cstring, Ptr{Ptr{UInt8}}),
        conninfo,
        errmsg,
    )
end

function PQconninfo(conn)
    return ccall((:PQconninfo, LIBPQ_HANDLE), Ptr{PQconninfoOption}, (Ptr{PGconn},), conn)
end

function PQconninfoFree(connOptions)
    return ccall(
        (:PQconninfoFree, LIBPQ_HANDLE), Cvoid, (Ptr{PQconninfoOption},), connOptions
    )
end

function PQresetStart(conn)
    return ccall((:PQresetStart, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQresetPoll(conn)
    return ccall(
        (:PQresetPoll, LIBPQ_HANDLE), PostgresPollingStatusType, (Ptr{PGconn},), conn
    )
end

function PQreset(conn)
    return ccall((:PQreset, LIBPQ_HANDLE), Cvoid, (Ptr{PGconn},), conn)
end

function PQgetCancel(conn)
    return ccall((:PQgetCancel, LIBPQ_HANDLE), Ptr{PGcancel}, (Ptr{PGconn},), conn)
end

function PQfreeCancel(cancel)
    return ccall((:PQfreeCancel, LIBPQ_HANDLE), Cvoid, (Ptr{PGcancel},), cancel)
end

function PQcancel(cancel, errbuf, errbufsize)
    return ccall(
        (:PQcancel, LIBPQ_HANDLE),
        Cint,
        (Ptr{PGcancel}, Cstring, Cint),
        cancel,
        errbuf,
        errbufsize,
    )
end

function PQrequestCancel(conn)
    return ccall((:PQrequestCancel, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQdb(conn)
    return ccall((:PQdb, LIBPQ_HANDLE), Cstring, (Ptr{PGconn},), conn)
end

function PQuser(conn)
    return ccall((:PQuser, LIBPQ_HANDLE), Cstring, (Ptr{PGconn},), conn)
end

function PQpass(conn)
    return ccall((:PQpass, LIBPQ_HANDLE), Cstring, (Ptr{PGconn},), conn)
end

function PQhost(conn)
    return ccall((:PQhost, LIBPQ_HANDLE), Cstring, (Ptr{PGconn},), conn)
end

function PQport(conn)
    return ccall((:PQport, LIBPQ_HANDLE), Cstring, (Ptr{PGconn},), conn)
end

function PQtty(conn)
    return ccall((:PQtty, LIBPQ_HANDLE), Cstring, (Ptr{PGconn},), conn)
end

function PQoptions(conn)
    return ccall((:PQoptions, LIBPQ_HANDLE), Cstring, (Ptr{PGconn},), conn)
end

function PQstatus(conn)
    return ccall((:PQstatus, LIBPQ_HANDLE), ConnStatusType, (Ptr{PGconn},), conn)
end

function PQtransactionStatus(conn)
    return ccall(
        (:PQtransactionStatus, LIBPQ_HANDLE), PGTransactionStatusType, (Ptr{PGconn},), conn
    )
end

function PQparameterStatus(conn, paramName)
    return ccall(
        (:PQparameterStatus, LIBPQ_HANDLE), Cstring, (Ptr{PGconn}, Cstring), conn, paramName
    )
end

function PQprotocolVersion(conn)
    return ccall((:PQprotocolVersion, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQserverVersion(conn)
    return ccall((:PQserverVersion, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQerrorMessage(conn)
    return ccall((:PQerrorMessage, LIBPQ_HANDLE), Cstring, (Ptr{PGconn},), conn)
end

function PQsocket(conn)
    return ccall((:PQsocket, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQbackendPID(conn)
    return ccall((:PQbackendPID, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQconnectionNeedsPassword(conn)
    return ccall((:PQconnectionNeedsPassword, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQconnectionUsedPassword(conn)
    return ccall((:PQconnectionUsedPassword, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQclientEncoding(conn)
    return ccall((:PQclientEncoding, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQsetClientEncoding(conn, encoding)
    return ccall(
        (:PQsetClientEncoding, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cstring), conn, encoding
    )
end

function PQsslInUse(conn)
    return ccall((:PQsslInUse, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQsslStruct(conn, struct_name)
    return ccall(
        (:PQsslStruct, LIBPQ_HANDLE), Ptr{Cvoid}, (Ptr{PGconn}, Cstring), conn, struct_name
    )
end

function PQsslAttribute(conn, attribute_name)
    return ccall(
        (:PQsslAttribute, LIBPQ_HANDLE),
        Cstring,
        (Ptr{PGconn}, Cstring),
        conn,
        attribute_name,
    )
end

function PQsslAttributeNames(conn)
    return ccall((:PQsslAttributeNames, LIBPQ_HANDLE), Ptr{Cstring}, (Ptr{PGconn},), conn)
end

function PQgetssl(conn)
    return ccall((:PQgetssl, LIBPQ_HANDLE), Ptr{Cvoid}, (Ptr{PGconn},), conn)
end

function PQinitSSL(do_init::Cint)
    return ccall((:PQinitSSL, LIBPQ_HANDLE), Cvoid, (Cint,), do_init)
end

function PQinitOpenSSL(do_ssl::Cint, do_crypto::Cint)
    return ccall((:PQinitOpenSSL, LIBPQ_HANDLE), Cvoid, (Cint, Cint), do_ssl, do_crypto)
end

function PQsetErrorVerbosity(conn, verbosity::PGVerbosity)
    return ccall(
        (:PQsetErrorVerbosity, LIBPQ_HANDLE),
        PGVerbosity,
        (Ptr{PGconn}, PGVerbosity),
        conn,
        verbosity,
    )
end

function PQsetErrorContextVisibility(conn, show_context::PGContextVisibility)
    return ccall(
        (:PQsetErrorContextVisibility, LIBPQ_HANDLE),
        PGContextVisibility,
        (Ptr{PGconn}, PGContextVisibility),
        conn,
        show_context,
    )
end

function PQtrace(conn, debug_port)
    return ccall(
        (:PQtrace, LIBPQ_HANDLE), Cvoid, (Ptr{PGconn}, Ptr{FILE}), conn, debug_port
    )
end

function PQuntrace(conn)
    return ccall((:PQuntrace, LIBPQ_HANDLE), Cvoid, (Ptr{PGconn},), conn)
end

function PQsetNoticeReceiver(conn, proc::PQnoticeReceiver, arg)
    return ccall(
        (:PQsetNoticeReceiver, LIBPQ_HANDLE),
        PQnoticeReceiver,
        (Ptr{PGconn}, PQnoticeReceiver, Ptr{Cvoid}),
        conn,
        proc,
        arg,
    )
end

function PQsetNoticeProcessor(conn, proc::PQnoticeProcessor, arg)
    return ccall(
        (:PQsetNoticeProcessor, LIBPQ_HANDLE),
        PQnoticeProcessor,
        (Ptr{PGconn}, PQnoticeProcessor, Ptr{Cvoid}),
        conn,
        proc,
        arg,
    )
end

function PQregisterThreadLock(newhandler::pgthreadlock_t)
    return ccall(
        (:PQregisterThreadLock, LIBPQ_HANDLE), pgthreadlock_t, (pgthreadlock_t,), newhandler
    )
end

function PQexec(conn, query)
    return ccall(
        (:PQexec, LIBPQ_HANDLE), Ptr{PGresult}, (Ptr{PGconn}, Cstring), conn, query
    )
end

function PQexecParams(
    conn,
    command,
    nParams,
    paramTypes,
    paramValues,
    paramLengths,
    paramFormats,
    resultFormat,
)
    return ccall(
        (:PQexecParams, LIBPQ_HANDLE),
        Ptr{PGresult},
        (Ptr{PGconn}, Cstring, Cint, Ptr{Oid}, Ptr{Ptr{UInt8}}, Ptr{Cint}, Ptr{Cint}, Cint),
        conn,
        command,
        nParams,
        paramTypes,
        paramValues,
        paramLengths,
        paramFormats,
        resultFormat,
    )
end

function PQprepare(conn, stmtName, query, nParams, paramTypes)
    return ccall(
        (:PQprepare, LIBPQ_HANDLE),
        Ptr{PGresult},
        (Ptr{PGconn}, Cstring, Cstring, Cint, Ptr{Oid}),
        conn,
        stmtName,
        query,
        nParams,
        paramTypes,
    )
end

function PQexecPrepared(
    conn, stmtName, nParams, paramValues, paramLengths, paramFormats, resultFormat
)
    return ccall(
        (:PQexecPrepared, LIBPQ_HANDLE),
        Ptr{PGresult},
        (Ptr{PGconn}, Cstring, Cint, Ptr{Ptr{UInt8}}, Ptr{Cint}, Ptr{Cint}, Cint),
        conn,
        stmtName,
        nParams,
        paramValues,
        paramLengths,
        paramFormats,
        resultFormat,
    )
end

function PQsendQuery(conn, query)
    return ccall((:PQsendQuery, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cstring), conn, query)
end

function PQsendQueryParams(
    conn,
    command,
    nParams,
    paramTypes,
    paramValues,
    paramLengths,
    paramFormats,
    resultFormat,
)
    return ccall(
        (:PQsendQueryParams, LIBPQ_HANDLE),
        Cint,
        (Ptr{PGconn}, Cstring, Cint, Ptr{Oid}, Ptr{Ptr{UInt8}}, Ptr{Cint}, Ptr{Cint}, Cint),
        conn,
        command,
        nParams,
        paramTypes,
        paramValues,
        paramLengths,
        paramFormats,
        resultFormat,
    )
end

function PQsendPrepare(conn, stmtName, query, nParams, paramTypes)
    return ccall(
        (:PQsendPrepare, LIBPQ_HANDLE),
        Cint,
        (Ptr{PGconn}, Cstring, Cstring, Cint, Ptr{Oid}),
        conn,
        stmtName,
        query,
        nParams,
        paramTypes,
    )
end

function PQsendQueryPrepared(
    conn, stmtName, nParams, paramValues, paramLengths, paramFormats, resultFormat
)
    return ccall(
        (:PQsendQueryPrepared, LIBPQ_HANDLE),
        Cint,
        (Ptr{PGconn}, Cstring, Cint, Ptr{Ptr{UInt8}}, Ptr{Cint}, Ptr{Cint}, Cint),
        conn,
        stmtName,
        nParams,
        paramValues,
        paramLengths,
        paramFormats,
        resultFormat,
    )
end

function PQsetSingleRowMode(conn)
    return ccall((:PQsetSingleRowMode, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQgetResult(conn)
    return ccall((:PQgetResult, LIBPQ_HANDLE), Ptr{PGresult}, (Ptr{PGconn},), conn)
end

function PQisBusy(conn)
    return ccall((:PQisBusy, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQconsumeInput(conn)
    return ccall((:PQconsumeInput, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQnotifies(conn)
    return ccall((:PQnotifies, LIBPQ_HANDLE), Ptr{PGnotify}, (Ptr{PGconn},), conn)
end

function PQputCopyData(conn, buffer, nbytes)
    return ccall(
        (:PQputCopyData, LIBPQ_HANDLE),
        Cint,
        (Ptr{PGconn}, Cstring, Cint),
        conn,
        buffer,
        nbytes,
    )
end

function PQputCopyEnd(conn, errormsg)
    return ccall(
        (:PQputCopyEnd, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cstring), conn, errormsg
    )
end

function PQgetCopyData(conn, buffer, async::Cint)
    return ccall(
        (:PQgetCopyData, LIBPQ_HANDLE),
        Cint,
        (Ptr{PGconn}, Ptr{Cstring}, Cint),
        conn,
        buffer,
        async,
    )
end

function PQgetline(conn, string, length::Cint)
    return ccall(
        (:PQgetline, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cstring, Cint), conn, string, length
    )
end

function PQputline(conn, string)
    return ccall((:PQputline, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cstring), conn, string)
end

function PQgetlineAsync(conn, buffer, bufsize::Cint)
    return ccall(
        (:PQgetlineAsync, LIBPQ_HANDLE),
        Cint,
        (Ptr{PGconn}, Cstring, Cint),
        conn,
        buffer,
        bufsize,
    )
end

function PQputnbytes(conn, buffer, nbytes::Cint)
    return ccall(
        (:PQputnbytes, LIBPQ_HANDLE),
        Cint,
        (Ptr{PGconn}, Cstring, Cint),
        conn,
        buffer,
        nbytes,
    )
end

function PQendcopy(conn)
    return ccall((:PQendcopy, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQsetnonblocking(conn, arg::Cint)
    return ccall((:PQsetnonblocking, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cint), conn, arg)
end

function PQisnonblocking(conn)
    return ccall((:PQisnonblocking, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQisthreadsafe()
    return ccall((:PQisthreadsafe, LIBPQ_HANDLE), Cint, ())
end

function PQping(conninfo)
    return ccall((:PQping, LIBPQ_HANDLE), PGPing, (Cstring,), conninfo)
end

function PQpingParams(keywords, values, expand_dbname::Cint)
    return ccall(
        (:PQpingParams, LIBPQ_HANDLE),
        PGPing,
        (Ptr{Ptr{UInt8}}, Ptr{Ptr{UInt8}}, Cint),
        keywords,
        values,
        expand_dbname,
    )
end

function PQflush(conn)
    return ccall((:PQflush, LIBPQ_HANDLE), Cint, (Ptr{PGconn},), conn)
end

function PQfn(
    conn, fnid::Cint, result_buf, result_len, result_is_int::Cint, args, nargs::Cint
)
    return ccall(
        (:PQfn, LIBPQ_HANDLE),
        Ptr{PGresult},
        (Ptr{PGconn}, Cint, Ptr{Cint}, Ptr{Cint}, Cint, Ptr{PQArgBlock}, Cint),
        conn,
        fnid,
        result_buf,
        result_len,
        result_is_int,
        args,
        nargs,
    )
end

function PQresultStatus(res)
    return ccall((:PQresultStatus, LIBPQ_HANDLE), ExecStatusType, (Ptr{PGresult},), res)
end

function PQresStatus(status::ExecStatusType)
    return ccall((:PQresStatus, LIBPQ_HANDLE), Cstring, (ExecStatusType,), status)
end

function PQresultErrorMessage(res)
    return ccall((:PQresultErrorMessage, LIBPQ_HANDLE), Cstring, (Ptr{PGresult},), res)
end

function PQresultVerboseErrorMessage(
    res, verbosity::PGVerbosity, show_context::PGContextVisibility
)
    return ccall(
        (:PQresultVerboseErrorMessage, LIBPQ_HANDLE),
        Ptr{UInt8},
        (Ptr{PGresult}, PGVerbosity, PGContextVisibility),
        res,
        verbosity,
        show_context,
    )
end

function PQresultErrorField(res, fieldcode)
    return ccall(
        (:PQresultErrorField, LIBPQ_HANDLE), Cstring, (Ptr{PGresult}, Cint), res, fieldcode
    )
end

function PQntuples(res)
    return ccall((:PQntuples, LIBPQ_HANDLE), Cint, (Ptr{PGresult},), res)
end

function PQnfields(res)
    return ccall((:PQnfields, LIBPQ_HANDLE), Cint, (Ptr{PGresult},), res)
end

function PQbinaryTuples(res)
    return ccall((:PQbinaryTuples, LIBPQ_HANDLE), Cint, (Ptr{PGresult},), res)
end

function PQfname(res, field_num)
    return ccall((:PQfname, LIBPQ_HANDLE), Cstring, (Ptr{PGresult}, Cint), res, field_num)
end

function PQfnumber(res, field_name)
    return ccall(
        (:PQfnumber, LIBPQ_HANDLE), Cint, (Ptr{PGresult}, Cstring), res, field_name
    )
end

function PQftable(res, field_num)
    return ccall((:PQftable, LIBPQ_HANDLE), Oid, (Ptr{PGresult}, Cint), res, field_num)
end

function PQftablecol(res, field_num)
    return ccall((:PQftablecol, LIBPQ_HANDLE), Cint, (Ptr{PGresult}, Cint), res, field_num)
end

function PQfformat(res, field_num)
    return ccall((:PQfformat, LIBPQ_HANDLE), Cint, (Ptr{PGresult}, Cint), res, field_num)
end

function PQftype(res, field_num)
    return ccall((:PQftype, LIBPQ_HANDLE), Oid, (Ptr{PGresult}, Cint), res, field_num)
end

function PQfsize(res, field_num)
    return ccall((:PQfsize, LIBPQ_HANDLE), Cint, (Ptr{PGresult}, Cint), res, field_num)
end

function PQfmod(res, field_num)
    return ccall((:PQfmod, LIBPQ_HANDLE), Cint, (Ptr{PGresult}, Cint), res, field_num)
end

function PQcmdStatus(res)
    return ccall((:PQcmdStatus, LIBPQ_HANDLE), Cstring, (Ptr{PGresult},), res)
end

function PQoidStatus(res)
    return ccall((:PQoidStatus, LIBPQ_HANDLE), Cstring, (Ptr{PGresult},), res)
end

function PQoidValue(res)
    return ccall((:PQoidValue, LIBPQ_HANDLE), Oid, (Ptr{PGresult},), res)
end

function PQcmdTuples(res)
    return ccall((:PQcmdTuples, LIBPQ_HANDLE), Cstring, (Ptr{PGresult},), res)
end

function PQgetvalue(res, tup_num, field_num)
    return ccall(
        (:PQgetvalue, LIBPQ_HANDLE),
        Ptr{UInt8},
        (Ptr{PGresult}, Cint, Cint),
        res,
        tup_num,
        field_num,
    )
end

function PQgetlength(res, tup_num, field_num)
    return ccall(
        (:PQgetlength, LIBPQ_HANDLE),
        Cint,
        (Ptr{PGresult}, Cint, Cint),
        res,
        tup_num,
        field_num,
    )
end

function PQgetisnull(res, tup_num, field_num)
    return ccall(
        (:PQgetisnull, LIBPQ_HANDLE),
        Cint,
        (Ptr{PGresult}, Cint, Cint),
        res,
        tup_num,
        field_num,
    )
end

function PQnparams(res)
    return ccall((:PQnparams, LIBPQ_HANDLE), Cint, (Ptr{PGresult},), res)
end

function PQparamtype(res, param_num)
    return ccall((:PQparamtype, LIBPQ_HANDLE), Oid, (Ptr{PGresult}, Cint), res, param_num)
end

function PQdescribePrepared(conn, stmt)
    return ccall(
        (:PQdescribePrepared, LIBPQ_HANDLE),
        Ptr{PGresult},
        (Ptr{PGconn}, Cstring),
        conn,
        stmt,
    )
end

function PQdescribePortal(conn, portal)
    return ccall(
        (:PQdescribePortal, LIBPQ_HANDLE),
        Ptr{PGresult},
        (Ptr{PGconn}, Cstring),
        conn,
        portal,
    )
end

function PQsendDescribePrepared(conn, stmt)
    return ccall(
        (:PQsendDescribePrepared, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cstring), conn, stmt
    )
end

function PQsendDescribePortal(conn, portal)
    return ccall(
        (:PQsendDescribePortal, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cstring), conn, portal
    )
end

function PQclear(res)
    return ccall((:PQclear, LIBPQ_HANDLE), Cvoid, (Ptr{PGresult},), res)
end

function PQfreemem(ptr)
    return ccall((:PQfreemem, LIBPQ_HANDLE), Cvoid, (Ptr{Cvoid},), ptr)
end

function PQmakeEmptyPGresult(conn, status::ExecStatusType)
    return ccall(
        (:PQmakeEmptyPGresult, LIBPQ_HANDLE),
        Ptr{PGresult},
        (Ptr{PGconn}, ExecStatusType),
        conn,
        status,
    )
end

function PQcopyResult(src, flags::Cint)
    return ccall(
        (:PQcopyResult, LIBPQ_HANDLE), Ptr{PGresult}, (Ptr{PGresult}, Cint), src, flags
    )
end

function PQsetResultAttrs(res, numAttributes::Cint, attDescs)
    return ccall(
        (:PQsetResultAttrs, LIBPQ_HANDLE),
        Cint,
        (Ptr{PGresult}, Cint, Ptr{PGresAttDesc}),
        res,
        numAttributes,
        attDescs,
    )
end

function PQresultAlloc(res, nBytes::Csize_t)
    return ccall(
        (:PQresultAlloc, LIBPQ_HANDLE), Ptr{Cvoid}, (Ptr{PGresult}, Csize_t), res, nBytes
    )
end

function PQsetvalue(res, tup_num::Cint, field_num::Cint, value, len::Cint)
    return ccall(
        (:PQsetvalue, LIBPQ_HANDLE),
        Cint,
        (Ptr{PGresult}, Cint, Cint, Cstring, Cint),
        res,
        tup_num,
        field_num,
        value,
        len,
    )
end

function PQescapeStringConn(conn, to, from, length::Csize_t, error)
    return ccall(
        (:PQescapeStringConn, LIBPQ_HANDLE),
        Csize_t,
        (Ptr{PGconn}, Cstring, Cstring, Csize_t, Ptr{Cint}),
        conn,
        to,
        from,
        length,
        error,
    )
end

function PQescapeLiteral(conn, str, len::Csize_t)
    return ccall(
        (:PQescapeLiteral, LIBPQ_HANDLE),
        Cstring,
        (Ptr{PGconn}, Cstring, Csize_t),
        conn,
        str,
        len,
    )
end

function PQescapeIdentifier(conn, str, len::Csize_t)
    return ccall(
        (:PQescapeIdentifier, LIBPQ_HANDLE),
        Cstring,
        (Ptr{PGconn}, Cstring, Csize_t),
        conn,
        str,
        len,
    )
end

function PQescapeByteaConn(conn, from, from_length::Csize_t, to_length)
    return ccall(
        (:PQescapeByteaConn, LIBPQ_HANDLE),
        Ptr{Cuchar},
        (Ptr{PGconn}, Ptr{Cuchar}, Csize_t, Ptr{Csize_t}),
        conn,
        from,
        from_length,
        to_length,
    )
end

function PQunescapeBytea(strtext, retbuflen::Ref{Csize_t})
    return ccall(
        (:PQunescapeBytea, LIBPQ_HANDLE),
        Ptr{Cuchar},
        (Ptr{Cuchar}, Ref{Csize_t}),
        strtext,
        retbuflen,
    )
end

function PQescapeString(to, from, length::Csize_t)
    return ccall(
        (:PQescapeString, LIBPQ_HANDLE),
        Csize_t,
        (Cstring, Cstring, Csize_t),
        to,
        from,
        length,
    )
end

function PQescapeBytea(from, from_length::Csize_t, to_length)
    return ccall(
        (:PQescapeBytea, LIBPQ_HANDLE),
        Ptr{Cuchar},
        (Ptr{Cuchar}, Csize_t, Ptr{Csize_t}),
        from,
        from_length,
        to_length,
    )
end

function PQprint(fout, res, ps)
    return ccall(
        (:PQprint, LIBPQ_HANDLE),
        Cvoid,
        (Ptr{FILE}, Ptr{PGresult}, Ptr{PQprintOpt}),
        fout,
        res,
        ps,
    )
end

function PQdisplayTuples(res, fp, fillAlign::Cint, fieldSep, printHeader::Cint, quiet::Cint)
    return ccall(
        (:PQdisplayTuples, LIBPQ_HANDLE),
        Cvoid,
        (Ptr{PGresult}, Ptr{FILE}, Cint, Cstring, Cint, Cint),
        res,
        fp,
        fillAlign,
        fieldSep,
        printHeader,
        quiet,
    )
end

function PQprintTuples(res, fout, printAttName::Cint, terseOutput::Cint, width::Cint)
    return ccall(
        (:PQprintTuples, LIBPQ_HANDLE),
        Cvoid,
        (Ptr{PGresult}, Ptr{FILE}, Cint, Cint, Cint),
        res,
        fout,
        printAttName,
        terseOutput,
        width,
    )
end

function lo_open(conn, lobjId::Oid, mode::Cint)
    return ccall(
        (:lo_open, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Oid, Cint), conn, lobjId, mode
    )
end

function lo_close(conn, fd::Cint)
    return ccall((:lo_close, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cint), conn, fd)
end

function lo_read(conn, fd::Cint, buf, len::Csize_t)
    return ccall(
        (:lo_read, LIBPQ_HANDLE),
        Cint,
        (Ptr{PGconn}, Cint, Cstring, Csize_t),
        conn,
        fd,
        buf,
        len,
    )
end

function lo_write(conn, fd::Cint, buf, len::Csize_t)
    return ccall(
        (:lo_write, LIBPQ_HANDLE),
        Cint,
        (Ptr{PGconn}, Cint, Cstring, Csize_t),
        conn,
        fd,
        buf,
        len,
    )
end

function lo_lseek(conn, fd::Cint, offset::Cint, whence::Cint)
    return ccall(
        (:lo_lseek, LIBPQ_HANDLE),
        Cint,
        (Ptr{PGconn}, Cint, Cint, Cint),
        conn,
        fd,
        offset,
        whence,
    )
end

function lo_lseek64(conn, fd::Cint, offset::pg_int64, whence::Cint)
    return ccall(
        (:lo_lseek64, LIBPQ_HANDLE),
        pg_int64,
        (Ptr{PGconn}, Cint, pg_int64, Cint),
        conn,
        fd,
        offset,
        whence,
    )
end

function lo_creat(conn, mode::Cint)
    return ccall((:lo_creat, LIBPQ_HANDLE), Oid, (Ptr{PGconn}, Cint), conn, mode)
end

function lo_create(conn, lobjId::Oid)
    return ccall((:lo_create, LIBPQ_HANDLE), Oid, (Ptr{PGconn}, Oid), conn, lobjId)
end

function lo_tell(conn, fd::Cint)
    return ccall((:lo_tell, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cint), conn, fd)
end

function lo_tell64(conn, fd::Cint)
    return ccall((:lo_tell64, LIBPQ_HANDLE), pg_int64, (Ptr{PGconn}, Cint), conn, fd)
end

function lo_truncate(conn, fd::Cint, len::Csize_t)
    return ccall(
        (:lo_truncate, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cint, Csize_t), conn, fd, len
    )
end

function lo_truncate64(conn, fd::Cint, len::pg_int64)
    return ccall(
        (:lo_truncate64, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Cint, pg_int64), conn, fd, len
    )
end

function lo_unlink(conn, lobjId::Oid)
    return ccall((:lo_unlink, LIBPQ_HANDLE), Cint, (Ptr{PGconn}, Oid), conn, lobjId)
end

function lo_import(conn, filename)
    return ccall((:lo_import, LIBPQ_HANDLE), Oid, (Ptr{PGconn}, Cstring), conn, filename)
end

function lo_import_with_oid(conn, filename, lobjId::Oid)
    return ccall(
        (:lo_import_with_oid, LIBPQ_HANDLE),
        Oid,
        (Ptr{PGconn}, Cstring, Oid),
        conn,
        filename,
        lobjId,
    )
end

function lo_export(conn, lobjId::Oid, filename)
    return ccall(
        (:lo_export, LIBPQ_HANDLE),
        Cint,
        (Ptr{PGconn}, Oid, Cstring),
        conn,
        lobjId,
        filename,
    )
end

function PQlibVersion()
    return ccall((:PQlibVersion, LIBPQ_HANDLE), Cint, ())
end

function PQmblen(s, encoding::Cint)
    return ccall((:PQmblen, LIBPQ_HANDLE), Cint, (Cstring, Cint), s, encoding)
end

function PQdsplen(s, encoding::Cint)
    return ccall((:PQdsplen, LIBPQ_HANDLE), Cint, (Cstring, Cint), s, encoding)
end

function PQenv2encoding()
    return ccall((:PQenv2encoding, LIBPQ_HANDLE), Cint, ())
end

function PQencryptPassword(passwd, user)
    return ccall(
        (:PQencryptPassword, LIBPQ_HANDLE), Cstring, (Cstring, Cstring), passwd, user
    )
end

function pg_char_to_encoding(name)
    return ccall((:pg_char_to_encoding, LIBPQ_HANDLE), Cint, (Cstring,), name)
end

function pg_encoding_to_char(encoding::Cint)
    return ccall((:pg_encoding_to_char, LIBPQ_HANDLE), Cstring, (Cint,), encoding)
end

function pg_valid_server_encoding_id(encoding::Cint)
    return ccall((:pg_valid_server_encoding_id, LIBPQ_HANDLE), Cint, (Cint,), encoding)
end
