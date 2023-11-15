\ o output / opdb__pg_replication_slots_ :VTAG.csv;

with src as (
    select s.slot_name,
        s.plugin,
        s.slot_type,
        s.datoid,
        s.database,
        s.temporary,
        s.active,
        s.active_pid,
        s.xmin,
        s.catalog_xmin,
        s.restart_lsn,
        s.confirmed_flush_lsn,
        s.wal_status,
        s.safe_wal_size,
        s.two_phase
    from pg_replication_slots s
)
select chr(39) || :PKEY || chr(39) as pkey,
    chr(39) || :DMA_SOURCE_ID || chr(39) as dma_source_id,
    chr(39) || :DMA_MANUAL_ID || chr(39) as dma_manual_id,
    src.slot_name,
    src.plugin,
    src.slot_type,
    src.datoid,
    src.database,
    src.temporary,
    src.active,
    src.active_pid,
    src.xmin,
    src.catalog_xmin,
    src.restart_lsn,
    src.confirmed_flush_lsn,
    src.wal_status,
    src.safe_wal_size,
    src.two_phase
from src;
