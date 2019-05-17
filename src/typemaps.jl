"""
    const PQ_SYSTEM_TYPES::Dict{Symbol, Oid}

Internal mapping of PostgreSQL's default types from PostgreSQL internal name to Oid.
The names may not correspond well to the common names, e.g., "char(n)" is :bpchar.
This dictionary is generated with the `deps/system_type_map.jl` script and contains only
PostgreSQL's system-defined types.
It is expected (but might not be guaranteed) that these are the same across versions and
installations.
"""
const PQ_SYSTEM_TYPES = Dict{Symbol, Oid}(
    :bool => 16, :bytea => 17, :char => 18, :name => 19, :int8 => 20, :int2 => 21,
    :int2vector => 22, :int4 => 23, :regproc => 24, :text => 25, :oid => 26, :tid => 27,
    :xid => 28, :cid => 29, :oidvector => 30, :pg_ddl_command => 32, :pg_type => 71,
    :pg_attribute => 75, :pg_proc => 81, :pg_class => 83, :json => 114, :xml => 142,
    :_xml => 143, :pg_node_tree => 194, :_json => 199, :smgr => 210,
    :index_am_handler => 325, :point => 600, :lseg => 601, :path => 602, :box => 603,
    :polygon => 604, :line => 628, :_line => 629, :cidr => 650, :_cidr => 651,
    :float4 => 700, :float8 => 701, :abstime => 702, :reltime => 703, :tinterval => 704,
    :unknown => 705, :circle => 718, :_circle => 719, :macaddr8 => 774, :_macaddr8 => 775,
    :money => 790, :_money => 791, :macaddr => 829, :inet => 869, :_bool => 1000,
    :_bytea => 1001, :_char => 1002, :_name => 1003, :_int2 => 1005, :_int2vector => 1006,
    :_int4 => 1007, :_regproc => 1008, :_text => 1009, :_tid => 1010, :_xid => 1011,
    :_cid => 1012, :_oidvector => 1013, :_bpchar => 1014, :_varchar => 1015, :_int8 => 1016,
    :_point => 1017, :_lseg => 1018, :_path => 1019, :_box => 1020, :_float4 => 1021,
    :_float8 => 1022, :_abstime => 1023, :_reltime => 1024, :_tinterval => 1025,
    :_polygon => 1027, :_oid => 1028, :aclitem => 1033, :_aclitem => 1034,
    :_macaddr => 1040, :_inet => 1041, :bpchar => 1042, :varchar => 1043, :date => 1082,
    :time => 1083, :timestamp => 1114, :_timestamp => 1115, :_date => 1182, :_time => 1183,
    :timestamptz => 1184, :_timestamptz => 1185, :interval => 1186, :_interval => 1187,
    :_numeric => 1231, :pg_database => 1248, :_cstring => 1263, :timetz => 1266,
    :_timetz => 1270, :bit => 1560, :_bit => 1561, :varbit => 1562, :_varbit => 1563,
    :numeric => 1700, :refcursor => 1790, :_refcursor => 2201, :regprocedure => 2202,
    :regoper => 2203, :regoperator => 2204, :regclass => 2205, :regtype => 2206,
    :_regprocedure => 2207, :_regoper => 2208, :_regoperator => 2209, :_regclass => 2210,
    :_regtype => 2211, :record => 2249, :cstring => 2275, :any => 2276, :anyarray => 2277,
    :void => 2278, :trigger => 2279, :language_handler => 2280, :internal => 2281,
    :opaque => 2282, :anyelement => 2283, :_record => 2287, :anynonarray => 2776,
    :pg_authid => 2842, :pg_auth_members => 2843, :_txid_snapshot => 2949, :uuid => 2950,
    :_uuid => 2951, :txid_snapshot => 2970, :fdw_handler => 3115, :pg_lsn => 3220,
    :_pg_lsn => 3221, :tsm_handler => 3310, :pg_ndistinct => 3361, :pg_dependencies => 3402,
    :anyenum => 3500, :tsvector => 3614, :tsquery => 3615, :gtsvector => 3642,
    :_tsvector => 3643, :_gtsvector => 3644, :_tsquery => 3645, :regconfig => 3734,
    :_regconfig => 3735, :regdictionary => 3769, :_regdictionary => 3770, :jsonb => 3802,
    :_jsonb => 3807, :anyrange => 3831, :event_trigger => 3838, :int4range => 3904,
    :_int4range => 3905, :numrange => 3906, :_numrange => 3907, :tsrange => 3908,
    :_tsrange => 3909, :tstzrange => 3910, :_tstzrange => 3911, :daterange => 3912,
    :_daterange => 3913, :int8range => 3926, :_int8range => 3927, :pg_shseclabel => 4066,
    :regnamespace => 4089, :_regnamespace => 4090, :regrole => 4096, :_regrole => 4097,
    :pg_subscription => 6101, :pg_attrdef => 10000, :pg_constraint => 10001,
    :pg_inherits => 10002, :pg_index => 10003, :pg_operator => 10004, :pg_opfamily => 10005,
    :pg_opclass => 10006, :pg_am => 10130, :pg_amop => 10131, :pg_amproc => 10841,
    :pg_language => 11253, :pg_largeobject_metadata => 11254, :pg_largeobject => 11255,
    :pg_aggregate => 11256, :pg_statistic_ext => 11257, :pg_statistic => 11258,
    :pg_rewrite => 11259, :pg_trigger => 11260, :pg_event_trigger => 11261,
    :pg_description => 11262, :pg_cast => 11263, :pg_enum => 11483, :pg_namespace => 11484,
    :pg_conversion => 11485, :pg_depend => 11486, :pg_db_role_setting => 11487,
    :pg_tablespace => 11488, :pg_pltemplate => 11489, :pg_shdepend => 11490,
    :pg_shdescription => 11491, :pg_ts_config => 11492, :pg_ts_config_map => 11493,
    :pg_ts_dict => 11494, :pg_ts_parser => 11495, :pg_ts_template => 11496,
    :pg_extension => 11497, :pg_foreign_data_wrapper => 11498, :pg_foreign_server => 11499,
    :pg_user_mapping => 11500, :pg_foreign_table => 11501, :pg_policy => 11502,
    :pg_replication_origin => 11503, :pg_default_acl => 11504, :pg_init_privs => 11505,
    :pg_seclabel => 11506, :pg_collation => 11507, :pg_partitioned_table => 11508,
    :pg_range => 11509, :pg_transform => 11510, :pg_sequence => 11511,
    :pg_publication => 11512, :pg_publication_rel => 11513, :pg_subscription_rel => 11514,
    :pg_toast_2604 => 11515, :pg_toast_2606 => 11516, :pg_toast_2609 => 11517,
    :pg_toast_1255 => 11518, :pg_toast_2618 => 11519, :pg_toast_3596 => 11520,
    :pg_toast_2619 => 11521, :pg_toast_3381 => 11522, :pg_toast_2620 => 11523,
    :pg_toast_2396 => 11524, :pg_toast_2964 => 11525, :pg_toast_3592 => 11526,
    :pg_roles => 11528, :pg_shadow => 11532, :pg_group => 11536, :pg_user => 11539,
    :pg_policies => 11542, :pg_rules => 11546, :pg_views => 11550, :pg_tables => 11554,
    :pg_matviews => 11558, :pg_indexes => 11562, :pg_sequences => 11566, :pg_stats => 11570,
    :pg_publication_tables => 11574, :pg_locks => 11578, :pg_cursors => 11581,
    :pg_available_extensions => 11584, :pg_available_extension_versions => 11587,
    :pg_prepared_xacts => 11590, :pg_prepared_statements => 11594, :pg_seclabels => 11597,
    :pg_settings => 11601, :pg_file_settings => 11606, :pg_hba_file_rules => 11609,
    :pg_timezone_abbrevs => 11612, :pg_timezone_names => 11615, :pg_config => 11618,
    :pg_stat_all_tables => 11621, :pg_stat_xact_all_tables => 11625,
    :pg_stat_sys_tables => 11629, :pg_stat_xact_sys_tables => 11633,
    :pg_stat_user_tables => 11636, :pg_stat_xact_user_tables => 11640,
    :pg_statio_all_tables => 11643, :pg_statio_sys_tables => 11647,
    :pg_statio_user_tables => 11650, :pg_stat_all_indexes => 11653,
    :pg_stat_sys_indexes => 11657, :pg_stat_user_indexes => 11660,
    :pg_statio_all_indexes => 11663, :pg_statio_sys_indexes => 11667,
    :pg_statio_user_indexes => 11670, :pg_statio_all_sequences => 11673,
    :pg_statio_sys_sequences => 11677, :pg_statio_user_sequences => 11680,
    :pg_stat_activity => 11683, :pg_stat_replication => 11687,
    :pg_stat_wal_receiver => 11691, :pg_stat_subscription => 11694, :pg_stat_ssl => 11697,
    :pg_replication_slots => 11700, :pg_stat_database => 11704,
    :pg_stat_database_conflicts => 11707, :pg_stat_user_functions => 11710,
    :pg_stat_xact_user_functions => 11714, :pg_stat_archiver => 11718,
    :pg_stat_bgwriter => 11721, :pg_stat_progress_vacuum => 11724,
    :pg_user_mappings => 11728, :pg_replication_origin_status => 11732,
    :cardinal_number => 12280, :character_data => 12282, :sql_identifier => 12283,
    :information_schema_catalog_name => 12285, :time_stamp => 12287, :yes_or_no => 12288,
    :applicable_roles => 12291, :administrable_role_authorizations => 12295,
    :attributes => 12298, :character_sets => 12302,
    :check_constraint_routine_usage => 12306, :check_constraints => 12310,
    :collations => 12314, :collation_character_set_applicability => 12318,
    :column_domain_usage => 12322, :column_privileges => 12326, :column_udt_usage => 12330,
    :columns => 12334, :constraint_column_usage => 12338, :constraint_table_usage => 12342,
    :domain_constraints => 12346, :domain_udt_usage => 12350, :domains => 12354,
    :enabled_roles => 12358, :key_column_usage => 12361, :parameters => 12365,
    :referential_constraints => 12369, :role_column_grants => 12373,
    :routine_privileges => 12376, :role_routine_grants => 12380, :routines => 12383,
    :schemata => 12387, :sequences => 12390, :sql_features => 12394,
    :pg_toast_12393 => 12396, :sql_implementation_info => 12399, :pg_toast_12398 => 12401,
    :sql_languages => 12404, :pg_toast_12403 => 12406, :sql_packages => 12409,
    :pg_toast_12408 => 12411, :sql_parts => 12414, :pg_toast_12413 => 12416,
    :sql_sizing => 12419, :pg_toast_12418 => 12421, :sql_sizing_profiles => 12424,
    :pg_toast_12423 => 12426, :table_constraints => 12429, :table_privileges => 12433,
    :role_table_grants => 12437, :tables => 12440, :transforms => 12444,
    :triggered_update_columns => 12448, :triggers => 12452, :udt_privileges => 12456,
    :role_udt_grants => 12460, :usage_privileges => 12463, :role_usage_grants => 12467,
    :user_defined_types => 12470, :view_column_usage => 12474, :view_routine_usage => 12478,
    :view_table_usage => 12482, :views => 12486, :data_type_privileges => 12490,
    :element_types => 12494, :_pg_foreign_table_columns => 12498, :column_options => 12502,
    :_pg_foreign_data_wrappers => 12505, :foreign_data_wrapper_options => 12508,
    :foreign_data_wrappers => 12511, :_pg_foreign_servers => 12514,
    :foreign_server_options => 12518, :foreign_servers => 12521,
    :_pg_foreign_tables => 12524, :foreign_table_options => 12528, :foreign_tables => 12531,
    :_pg_user_mappings => 12534, :user_mapping_options => 12538, :user_mappings => 12542,
)

# If we ever need the reverse mapping:
# const PQ_SYSTEM_OIDS = Dict{Oid, Symbol}((v => k) for (k, v) in PQ_SYSTEM_TYPES)

"""
    oid(typ::Union{Symbol, String, Integer}) -> LibPQ.Oid

Convert a PostgreSQL type from an `AbstractString` or `Symbol` representation to its oid
representation.
Integers are converted directly to `LibPQ.Oid`s.
"""
function oid end

oid(typ::Symbol) = PQ_SYSTEM_TYPES[typ]
oid(o::Integer) = convert(Oid, o)
oid(typ::AbstractString) = oid(Symbol(typ))

"A mapping from PostgreSQL Oid to Julia type."
struct PQTypeMap <: AbstractDict{Oid, Type}
    type_map::Dict{Oid, Type}
end

PQTypeMap(type_map::PQTypeMap) = type_map
PQTypeMap(type_map::AbstractDict{Oid, Type}) = PQTypeMap(Dict(type_map))
PQTypeMap() = PQTypeMap(Dict{Oid, Type}())

"""
    PQTypeMap(d::AbstractDict) -> PQTypeMap

Creates a `PQTypeMap` from any mapping from PostgreSQL types to Julia types.
Each PostgreSQL type is passed through [`oid`](@ref) and so can be specified as an Oid or
PostgreSQL's internal name for the type (as a `Symbol` or `AbstractString`).
These names are stored in the keys of [`PQ_SYSTEM_TYPES`](@ref).
"""
function PQTypeMap(user_map::AbstractDict)
    type_map = PQTypeMap()

    for (k, v) in user_map
        type_map[oid(k)] = v
    end

    return type_map
end

const LayerPQTypeMap = LayerDict{Oid, Type}

"""
    Base.getindex(tmap::PQTypeMap, typ) -> Type

Get the Julia type corresponding to the given PostgreSQL type (any type accepted by
[`oid`](@ref)) according to `tmap`.
"""
Base.getindex(tmap::PQTypeMap, typ) = tmap.type_map[oid(typ)]

"""
    Base.setindex!(tmap::PQTypeMap, val::Type, typ)

Set the Julia type corresponding to the given PostgreSQL type (any type accepted by
[`oid`](@ref)) in `tmap`.
"""
function Base.setindex!(tmap::PQTypeMap, val::Type, typ)
    setindex!(tmap.type_map, val, oid(typ))
end

Base.iterate(tmap::PQTypeMap) = iterate(tmap.type_map)
Base.iterate(tmap::PQTypeMap, i) = iterate(tmap.type_map, i)

Base.length(tmap::PQTypeMap) = length(tmap.type_map)
Base.keys(tmap::PQTypeMap) = keys(tmap.type_map)

"""
    const _DEFAULT_TYPE_MAP::PQTypeMap

The [`PQTypeMap`](@ref) containing the default type mappings for LibPQ.jl.
This should not be mutated; LibPQ-level type mappings can be added to
[`LIBPQ_TYPE_MAP`](@ref).
"""
const _DEFAULT_TYPE_MAP = PQTypeMap(Dict{Oid, Type}())

# type alias for convenience
const ColumnTypeMap = Dict{Cint, Type}

"""
A mapping from Oid and Julia type pairs to the function for converting a PostgreSQL value
with said Oid to said Julia type.
"""
struct PQConversions <: AbstractDict{Tuple{Oid, Type}, Base.Callable}
    func_map::Dict{Tuple{Oid, Type}, Base.Callable}
end

PQConversions(func_map::PQConversions) = func_map
function PQConversions(func_map::AbstractDict{Tuple{Oid, Type}, Base.Callable})
    return PQConversions(Dict{Tuple{Oid, Type}, Base.Callable}(func_map))
end
PQConversions() = PQConversions(Dict{Tuple{Oid, Type}, Base.Callable}())

function PQConversions(user_map::AbstractDict)
    func_map = PQConversions()

    for (k, v) in user_map
        func_map[k] = v
    end

    return func_map
end

"""
    Base.getindex(cmap::PQConversions, oid_typ::Tuple{Any, Type}) -> Base.Callable

Get the function according to `cmap` for converting a PostgreSQL value of some PostgreSQL
type (any type accepted by [`oid`](@ref)) to some Julia type.
"""
function Base.getindex(cmap::PQConversions, oid_typ::Tuple{Any, Type})
    getindex(cmap.func_map, (oid(oid_typ[1]), oid_typ[2]))
end

"""
    Base.setindex!(cmap::PQConversions, val::Base.Callable, oid_typ::Tuple{Any, Type})

Set the function in `cmap` for converting a PostgreSQL value of some PostgreSQL type (any
type accepted by [`oid`](@ref)) to some Julia type.
"""
function Base.setindex!(
    cmap::PQConversions,
    val::Base.Callable,
    oid_typ::Tuple{Any, Type},
)
    setindex!(cmap.func_map, val, (oid(oid_typ[1]), oid_typ[2]))
end

Base.iterate(cmap::PQConversions) = iterate(cmap.func_map)
Base.iterate(cmap::PQConversions, i) = iterate(cmap.func_map, i)

Base.length(cmap::PQConversions) = length(cmap.func_map)
Base.keys(cmap::PQConversions) = keys(cmap.func_map)

"""
    const _DEFAULT_CONVERSIONS::PQConversions

The [`PQConversions`](@ref) containing the default conversion functions for LibPQ.jl.
This should not be mutated; LibPQ-level conversion functions can be added to
[`LIBPQ_CONVERSIONS`](@ref).
"""
const _DEFAULT_CONVERSIONS = PQConversions()

## WRAPPER TYPES

"A one-byte character type for correspondence with PostgreSQL's one-byte \"char\" type."
primitive type PQChar 8 end

Base.UInt8(c::PQChar) = reinterpret(UInt8, c)
Base.Char(c::PQChar) = Char(UInt8(c))

PQChar(i::UInt8) = reinterpret(PQChar, i)
PQChar(c::Char) = PQChar(UInt8(c))

Base.convert(::Type{T}, c::PQChar) where {T <: Union{UInt8, Char}} = T(c)
Base.convert(::Type{T}, c::PQChar) where {T <: Number} = T(UInt8(c))
Base.convert(::Type{PQChar}, c::Union{UInt8, Char}) = PQChar(c)

Base.show(io::IO, c::PQChar) = show(io, Char(c))
Base.print(io::IO, c::PQChar) = print(io, Char(c))

Base.isless(c1::PQChar, c2::PQChar) = isless(UInt8(c1), UInt8(c2))
Base.:(==)(c1::PQChar, c2::PQChar) = UInt8(c1) == UInt8(c2)

Base.:(==)(c1::PQChar, c2::Char) = Char(c1) == c2
Base.:(==)(c1::PQChar, c2::UInt8) = c1 == PQChar(c2)
Base.:(==)(c1::Union{UInt8, Char}, c2::PQChar) = c2 == c1
