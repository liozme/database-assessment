with global_status as (
    select upper(variable_name) as variable_name,
        variable_value
    from performance_schema.global_status a
    where a.variable_name not in ('FT_BOOLEAN_SYNTAX')
        and a.variable_name not like '%PUBLIC_KEY'
        and a.variable_name not like '%PRIVATE_KEY'
),
all_vars as (
    select variable_name,
        variable_value
    from (
            select upper(variable_name) as variable_name,
                variable_value
            from performance_schema.global_variables
            union
            select upper(variable_name),
                variable_value
            from performance_schema.session_variables
            where variable_name not in (
                    select variable_name
                    from performance_schema.global_variables
                )
        ) a
    where a.variable_name not in ('FT_BOOLEAN_SYNTAX')
        and a.variable_name not like '%PUBLIC_KEY'
        and a.variable_name not like '%PRIVATE_KEY'
),
all_plugins as (
    select if(agg.mysqlx_plugin > 0, 1, 0) as mysqlx_plugin_enabled,
        if(agg.memcached_plugin > 0, 1, 0) as memcached_plugin_enabled,
        if(agg.clone_plugin > 0, 1, 0) as clone_plugin_enabled,
        if(agg.keyring_plugin > 0, 1, 0) as keyring_plugin_enabled,
        if(agg.validate_password_plugin > 0, 1, 0) as validate_password_plugin_enabled,
        if(agg.thread_pool_plugin > 0, 1, 0) as thread_pool_plugin_enabled,
        if(agg.firewall_plugin > 0, 1, 0) as firewall_plugin_enabled
    from (
            select sum(
                    if(
                        upper(p.plugin_name) like '%MYSQLX%',
                        1,
                        0
                    )
                ) as mysqlx_plugin,
                sum(
                    if(
                        upper(p.plugin_name) like '%MEMCACHED%',
                        1,
                        0
                    )
                ) as memcached_plugin,
                sum(
                    if(
                        upper(p.plugin_name) like '%CLONE%',
                        1,
                        0
                    )
                ) as clone_plugin,
                sum(
                    if(
                        upper(p.plugin_name) like '%KEYRING%',
                        1,
                        0
                    )
                ) as keyring_plugin,
                sum(
                    if(
                        upper(p.plugin_name) like '%VALIDATE_PASSWORD%',
                        1,
                        0
                    )
                ) as validate_password_plugin,
                sum(
                    if(
                        upper(p.plugin_name) like '%THREAD_POOL%',
                        1,
                        0
                    )
                ) as thread_pool_plugin,
                sum(
                    if(
                        upper(p.plugin_name) like '%FIREWALL%',
                        1,
                        0
                    )
                ) as firewall_plugin
            from (
                    select p.plugin_name as plugin_name,
                        p.PLUGIN_STATUS
                    from information_schema.PLUGINS p
                ) p
        ) agg
),
data_summary as (
    select table_schema,
        count(table_name) as total_table_count,
        sum(if(upper(table_engine) = 'INNODB', 1, 0)) as innodb_table_count,
        sum(has_primary_key) as total_tables_with_primary_key,
        sum(if(has_primary_key = 0, 1, 0)) as total_tables_without_primary_key,
        sum(if(upper(table_engine) != 'INNODB', 1, 0)) as non_innodb_table_count,
        sum(table_rows) as total_row_count,
        sum(
            if(upper(table_engine) = 'INNODB', table_rows, 0)
        ) as innodb_table_row_count,
        sum(
            if(upper(table_engine) != 'INNODB', table_rows, 0)
        ) as non_innodb_table_row_count,
        sum(data_length) as total_data_size_bytes,
        sum(
            if(upper(table_engine) = 'INNODB', data_length, 0)
        ) as innodb_data_size_bytes,
        sum(
            if(upper(table_engine) != 'INNODB', data_length, 0)
        ) as non_innodb_data_size_bytes,
        sum(index_length) as total_index_size_bytes,
        sum(
            if(upper(table_engine) = 'INNODB', index_length, 0)
        ) as innodb_index_size_bytes,
        sum(
            if(upper(table_engine) != 'INNODB', index_length, 0)
        ) as non_innodb_index_size_bytes,
        sum(total_length) as total_size_bytes,
        sum(
            if(upper(table_engine) = 'INNODB', total_length, 0)
        ) as innodb_total_size_bytes,
        sum(
            if(upper(table_engine) != 'INNODB', total_length, 0)
        ) as non_innodb_total_size_bytes
    from (
            select t.table_schema as table_schema,
                t.table_name as table_name,
                t.table_rows as table_rows,
                t.DATA_LENGTH as DATA_LENGTH,
                t.INDEX_LENGTH as INDEX_LENGTH,
                t.DATA_LENGTH + t.INDEX_LENGTH as total_length,
                t.ROW_FORMAT as row_format,
                t.TABLE_TYPE as table_type,
                t.ENGINE as table_engine,
                if(pks.table_name is not null, 1, 0) as has_primary_key
            from information_schema.TABLES t
                left join (
                    select table_schema,
                        TABLE_NAME
                    from information_schema.statistics
                    where table_schema not in (
                            'mysql',
                            'information_schema',
                            'performance_schema',
                            'sys'
                        )
                    group by table_schema,
                        TABLE_NAME,
                        index_name
                    having SUM(
                            if(
                                non_unique = 0
                                and NULLABLE != 'YES',
                                1,
                                0
                            )
                        ) = count(*)
                ) pks on (
                    t.table_schema = pks.table_schema
                    and t.TABLE_NAME = pks.TABLE_NAME
                )
            where t.table_schema not in (
                    'mysql',
                    'information_schema',
                    'performance_schema',
                    'sys'
                )
        ) user_tables
    group by user_tables.table_schema
),
calculated_metrics as (
    select 'IS_MARIADB' as variable_name,
        if(upper(gv.variable_value) like '%MARIADB%', 1, 0) as variable_value
    from performance_schema.global_variables gv
    where gv.variable_name = 'VERSION'
    union
    select 'TABLE_SIZE' as variable_name,
        total_data_size_bytes as variable_value
    from data_summary
    union
    select 'TABLE_NO_INNODB_SIZE' as variable_name,
        non_innodb_data_size_bytes as variable_value
    from data_summary
    union
    select 'TABLE_INNODB_SIZE' as variable_name,
        innodb_data_size_bytes as variable_value
    from data_summary
    union
    select 'TABLE_COUNT' as variable_name,
        total_table_count as variable_value
    from data_summary
    union
    select 'TABLE_NO_INNODB_COUNT' as variable_name,
        non_innodb_table_count as variable_value
    from data_summary
    union
    select 'TABLE_INNODB_COUNT' as variable_name,
        innodb_table_count as variable_value
    from data_summary
    union
    select 'TABLE_NO_PK_COUNT' as variable_name,
        total_tables_without_primary_key as variable_value
    from data_summary
    union
    select 'MYSQLX_PLUGIN' as variable_name,
        p.mysqlx_plugin_enabled as variable_value
    from all_plugins p
    union
    select 'MEMCACHED_PLUGIN' as variable_name,
        p.memcached_plugin_enabled as variable_value
    from all_plugins p
    union
    select 'CLONE_PLUGIN' as variable_name,
        p.clone_plugin_enabled as variable_value
    from all_plugins p
    union
    select 'KEYRING_PLUGIN' as variable_name,
        p.keyring_plugin_enabled as variable_value
    from all_plugins p
    union
    select 'VALIDATE_PASSWORD_PLUGIN' as variable_name,
        p.validate_password_plugin_enabled as variable_value
    from all_plugins p
    union
    select 'THREAD_POOL_PLUGIN' as variable_name,
        p.thread_pool_plugin_enabled as variable_value
    from all_plugins p
    union
    select 'FIREWALL_PLUGIN' as variable_name,
        p.firewall_plugin_enabled as variable_value
    from all_plugins p
),
src as (
    select 'ALL_VARIABLES' as variable_category,
        variable_name,
        variable_value
    from all_vars
    union
    select 'GLOBAL_STATUS' as variable_category,
        variable_name,
        variable_value
    from global_status
    union
    select 'CALCULATED_METRIC' as variable_category,
        variable_name,
        variable_value
    from calculated_metrics
)
select distinct concat(char(34), @PKEY, char(34)) as pkey,
    concat(char(34), @DMA_SOURCE_ID, char(34)) as dma_source_id,
    concat(char(34), @DMA_MANUAL_ID, char(34)) as dma_manual_id,
    concat(char(34), src.variable_category, char(34)) as variable_category,
    concat(char(34), src.variable_name, char(34)) as variable_name,
    concat(char(34), src.variable_value, char(34)) as variable_value
from src;
