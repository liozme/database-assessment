\o output/opdb__sproccount_:VTAG.csv
SELECT proowner::varchar(255),
       l.lanname,
       count(*),
       chr(39) || :DMA_SOURCE_ID || chr(39) AS DMA_SOURCE_ID, chr(39) || :DMA_MANUAL_ID || chr(39) AS DMA_MANUAL_ID
FROM pg_proc pr
JOIN pg_language l ON l.oid = pr.prolang
GROUP BY 1,
         2
