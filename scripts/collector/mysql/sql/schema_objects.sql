with src as (
    select i.CONSTRAINT_CATALOG as object_catalog,
        i.CONSTRAINT_SCHEMA as object_schema,
        'CONSTRAINT' as object_category,
        concat(i.CONSTRAINT_TYPE, ' CONSTRAINT') as object_type,
        i.TABLE_SCHEMA as object_owner_schema,
        i.TABLE_NAME as object_owner,
        i.CONSTRAINT_NAME as object_name
    from information_schema.TABLE_CONSTRAINTS i
    where i.CONSTRAINT_SCHEMA not in (
            'mysql',
            'information_schema',
            'performance_schema',
            'sys'
        )
    union
    select i.TRIGGER_CATALOG as object_catalog,
        i.TRIGGER_SCHEMA as object_schema,
        'TRIGGER' as object_category,
        concat(
            i.ACTION_TIMING,
            ' ',
            i.EVENT_MANIPULATION,
            ' TRIGGER'
        ) as object_type,
        i.TRIGGER_SCHEMA as object_owner_schema,
        i.definer as object_owner,
        i.TRIGGER_NAME as object_name
    from information_schema.TRIGGERS i
    where i.TRIGGER_SCHEMA not in (
            'mysql',
            'information_schema',
            'performance_schema',
            'sys'
        )
    union
    select i.TABLE_CATALOG as object_catalog,
        i.TABLE_SCHEMA as object_schema,
        'VIEW' as object_category,
        i.TABLE_TYPE as object_type,
        null as object_schema_schema,
        null as object_owner,
        i.TABLE_NAME as object_name
    from information_schema.TABLES i
    where i.table_type = 'VIEW'
        and i.TABLE_SCHEMA not in (
            'mysql',
            'information_schema',
            'performance_schema',
            'sys'
        )
    union
    select i.TABLE_CATALOG as object_catalog,
        i.TABLE_SCHEMA as object_schema,
        'TABLE' as object_category,
        if(
            pt.PARTITION_METHOD is null,
            'TABLE',
            if(
                pt.SUBPARTITION_METHOD is not null,
                concat(
                    'TABLE-COMPOSITE_PARTITIONED-',
                    pt.PARTITION_METHOD,
                    '-',
                    pt.SUBPARTITION_METHOD
                ),
                concat('TABLE-PARTITIONED-', pt.PARTITION_METHOD)
            )
        ) as object_type,
        null as object_schema_schema,
        null as object_owner,
        i.TABLE_NAME as object_name
    from information_schema.TABLES i
        left join (
            select TABLE_SCHEMA,
                TABLE_NAME,
                PARTITION_METHOD,
                SUBPARTITION_METHOD,
                count(1) as PARTITION_COUNT
            from information_schema.PARTITIONS
            where table_schema not in (
                    'mysql',
                    'information_schema',
                    'performance_schema',
                    'sys'
                )
            group by TABLE_SCHEMA,
                TABLE_NAME,
                PARTITION_METHOD,
                SUBPARTITION_METHOD
        ) pt on (
            i.TABLE_NAME = pt.TABLE_NAME
            and i.TABLE_SCHEMA = pt.TABLE_SCHEMA
        )
    where i.table_type != 'VIEW'
        and i.TABLE_SCHEMA not in (
            'mysql',
            'information_schema',
            'performance_schema',
            'sys'
        )
    union
    select i.ROUTINE_CATALOG as object_catalog,
        i.ROUTINE_SCHEMA as object_schema,
        'PROCEDURE' as object_category,
        i.ROUTINE_TYPE as object_type,
        i.ROUTINE_SCHEMA as object_owner_schema,
        i.definer as object_owner,
        i.ROUTINE_NAME as object_name
    from information_schema.ROUTINES i
    where i.ROUTINE_TYPE = 'PROCEDURE'
        and i.ROUTINE_SCHEMA not in (
            'mysql',
            'information_schema',
            'performance_schema',
            'sys'
        )
    union
    select i.ROUTINE_CATALOG as object_catalog,
        i.ROUTINE_SCHEMA as object_schema,
        'FUNCTION' as object_category,
        i.ROUTINE_TYPE as object_type,
        i.ROUTINE_SCHEMA as object_owner_schema,
        i.definer as object_owner,
        i.ROUTINE_NAME as object_name
    from information_schema.ROUTINES i
    where i.ROUTINE_TYPE = 'FUNCTION'
        and i.ROUTINE_SCHEMA not in (
            'mysql',
            'information_schema',
            'performance_schema',
            'sys'
        )
    union
    select i.EVENT_CATALOG as object_catalog,
        i.EVENT_SCHEMA as object_schema,
        'EVENT' as object_category,
        i.EVENT_TYPE as object_type,
        i.EVENT_SCHEMA as object_owner_schema,
        i.definer as object_owner,
        i.EVENT_NAME as object_name
    from information_schema.EVENTS i
    where i.EVENT_SCHEMA not in (
            'mysql',
            'information_schema',
            'performance_schema',
            'sys'
        )
    union
    select i.TABLE_CATALOG as object_catalog,
        i.TABLE_SCHEMA as object_schema,
        'INDEX' as object_category,
        case
            when i.INDEX_TYPE = 'BTREE' then 'INDEX'
            when i.INDEX_TYPE = 'HASH' then 'INDEX-HASH'
            when i.INDEX_TYPE = 'FULLTEXT' then 'INDEX-FULLTEXT'
            when i.INDEX_TYPE = 'SPATIAL' then 'INDEX-SPATIAL'
            else 'INDEX-UNCATEGORIZED'
        end as object_type,
        i.TABLE_SCHEMA as object_owner_schema,
        i.TABLE_NAME as object_owner,
        i.INDEX_NAME as object_name
    from information_schema.STATISTICS i
    where i.INDEX_NAME != 'PRIMARY'
        and i.TABLE_SCHEMA not in (
            'mysql',
            'information_schema',
            'performance_schema',
            'sys'
        )
)
select concat(char(34), @PKEY, char(34)) as pkey,
    concat(char(34), @DMA_SOURCE_ID, char(34)) as dma_source_id,
    concat(char(34), @DMA_MANUAL_ID, char(34)) as dma_manual_id,
    concat(char(34), src.object_catalog, char(34)) as object_catalog,
    concat(char(34), src.object_schema, char(34)) as object_schema,
    concat(char(34), src.object_category, char(34)) as object_category,
    concat(char(34), src.object_type, char(34)) as object_type,
    concat(char(34), src.object_owner_schema, char(34)) as object_owner_schema,
    concat(char(34), src.object_owner, char(34)) as object_owner,
    concat(char(34), src.object_name, char(34)) as object_name
from src;
