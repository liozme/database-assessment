/*
Copyright 2023 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

*/

SET NOCOUNT ON;
SET LANGUAGE us_english;

DECLARE @PKEY AS VARCHAR(256)
DECLARE @CLOUDTYPE AS VARCHAR(256)
DECLARE @ASSESSMENT_DATABSE_NAME AS VARCHAR(256)
DECLARE @PRODUCT_VERSION AS INTEGER
DECLARE @validDB AS INTEGER
DECLARE @DMA_SOURCE_ID AS VARCHAR(256)
DECLARE @DMA_MANUAL_ID AS VARCHAR(256)

SELECT @PKEY = N'$(pkey)';
SELECT @CLOUDTYPE = 'NONE'
SELECT @ASSESSMENT_DATABSE_NAME = N'$(database)';
SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(nvarchar, SERVERPROPERTY('productversion')), 4));
SELECT @validDB = 0
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

IF @ASSESSMENT_DATABSE_NAME = 'all'
   SELECT @ASSESSMENT_DATABSE_NAME = '%'

IF UPPER(@@VERSION) LIKE '%AZURE%'
	SELECT @CLOUDTYPE = 'AZURE'

IF OBJECT_ID('tempdb..#objectList') IS NOT NULL  
   DROP TABLE #objectList;

CREATE TABLE #objectList(
    database_name nvarchar(255)
    ,schema_name nvarchar(255)
    ,object_name nvarchar(255)
    ,object_type nvarchar(255)
    ,object_type_desc nvarchar(255)
    ,object_count nvarchar(255)
    ,lines_of_code nvarchar(255)
	,associated_table_name nvarchar(255));

BEGIN
    BEGIN
        SELECT @validDB = COUNT(1)
        FROM sys.databases 
        WHERE name NOT IN ('master','model','msdb','tempdb','distribution','reportserver', 'reportservertempdb','resource','rdsadmin')
        AND name like @ASSESSMENT_DATABSE_NAME
        AND state = 0
    END

    BEGIN TRY
        IF @validDB <> 0
        BEGIN
            exec ('
            INSERT INTO #objectList
            SELECT 
            database_name 
            , schema_name
            , NameOfObject as object_name
            , RTRIM(LTRIM(type)) as type
            , type_desc
            , count(*) AS object_count
            , ISNULL(SUM(LinesOfCode),0) AS lines_of_code
            , associated_table_name
            FROM 
            (
            SELECT
            DB_NAME(DB_ID()) as database_name,
            s.name as schema_name,
            RTRIM(LTRIM(o.type)) as type, 
            o.type_desc, 
            ISNULL(LEN(a.definition)- LEN(
                REPLACE(
                a.definition, 
                CHAR(10), 
                ''''
                )
            ),0) AS LinesOfCode, 
            OBJECT_NAME(o.object_id) AS NameOfObject ,
            NULL as associated_table_name
            FROM 
            sys.objects o
            JOIN sys.schemas s ON s.schema_id = o.schema_id
            LEFT OUTER JOIN sys.all_sql_modules a ON a.OBJECT_ID = o.object_id
            WHERE 
            o.type NOT IN (
                ''S'' --SYSTEM_TABLE
                , 
                ''IT'' --INTERNAL_TABLE
                ,
                ''F'' --FOREIGN KEY
                ,
                ''PK''  --PRIMARY KEY
                ,
                ''C''  -- CHECK CONSTRAINT
                ,
                ''D''  --DEFAULT CONSTRAINT
                ,
                ''UQ''  --UNIQUE CONSTRAINT
                ,
                ''TR'' --TRIGGER
                ,
                ''V'' --VIEW
                ) 
            AND OBJECTPROPERTY(o.object_id, ''IsMSShipped'') = 0
            UNION
            select DB_NAME(DB_ID()) as database_name,
            s.name as schema_name,
            RTRIM(LTRIM(type)) as type,
            type_desc,
            ISNULL(LEN(a.definition)- LEN(
                REPLACE(
                a.definition, 
                CHAR(10), 
                ''''
                )
            ),0) AS LinesOfCode,
            cc.name AS NameOfObject ,
            object_name(cc.parent_object_id) AS associated_table_name
            from sys.check_constraints cc
            JOIN sys.schemas s ON s.schema_id = cc.schema_id
            LEFT OUTER JOIN sys.all_sql_modules a ON a.OBJECT_ID = cc.object_id
            WHERE cc.is_ms_shipped = 0
            UNION
            select DB_NAME(DB_ID()) as database_name,
            s.name as schema_name,
            RTRIM(LTRIM(type)) as type,
            type_desc,
            ISNULL(LEN(a.definition)- LEN(
                REPLACE(
                a.definition, 
                CHAR(10), 
                ''''
                )
            ),0) AS LinesOfCode,
            fk.name AS NameOfObject ,
            object_name(fk.parent_object_id) AS associated_table_name
            from sys.foreign_keys fk
            JOIN sys.schemas s ON s.schema_id = fk.schema_id
            LEFT OUTER JOIN sys.all_sql_modules a ON a.OBJECT_ID = fk.object_id
            WHERE fk.is_ms_shipped = 0
            UNION
            select DB_NAME(DB_ID()) as database_name,
            s.name as schema_name,
            RTRIM(LTRIM(type)) as type,
            type_desc,
            ISNULL(LEN(a.definition)- LEN(
                REPLACE(
                a.definition, 
                CHAR(10), 
                ''''
                )
            ),0) AS LinesOfCode,
            dc.name AS NameOfObject ,
            object_name(dc.parent_object_id) AS associated_table_name
            from sys.default_constraints dc
            JOIN sys.schemas s ON s.schema_id = dc.schema_id
            LEFT OUTER JOIN sys.all_sql_modules a ON a.OBJECT_ID = dc.object_id
            WHERE dc.is_ms_shipped = 0
            UNION
            select DB_NAME(DB_ID()) as database_name,
            s.name as schema_name,
            RTRIM(LTRIM(type)) as type,
            type_desc,
            ISNULL(LEN(a.definition)- LEN(
                REPLACE(
                a.definition, 
                CHAR(10), 
                ''''
                )
            ),0) AS LinesOfCode,
            kc.name AS NameOfObject,
            object_name(kc.parent_object_id) AS associated_table_name
            from sys.key_constraints kc
            JOIN sys.schemas s ON s.schema_id = kc.schema_id
            LEFT OUTER JOIN sys.all_sql_modules a ON a.OBJECT_ID = kc.object_id
            WHERE kc.is_ms_shipped = 0
            UNION
            select DB_NAME(DB_ID()) as database_name,
            s.name as schema_name,
            RTRIM(LTRIM(t.type)) as type,
            t.type_desc,
            ISNULL(LEN(a.definition)- LEN(
                REPLACE(
                a.definition, 
                CHAR(10), 
                ''''
                )
            ),0) AS LinesOfCode,
            t.name AS NameOfObject ,
            object_name(t.parent_id) AS associated_table_name
            from sys.triggers t
            JOIN sys.tables tbl ON tbl.object_id = t.parent_id
            LEFT OUTER JOIN sys.schemas s ON s.schema_id = tbl.schema_id
            LEFT OUTER JOIN sys.all_sql_modules a ON a.OBJECT_ID = t.object_id
            WHERE t.is_ms_shipped = 0
            UNION
            select DB_NAME(DB_ID()) as database_name,
            s.name as schema_name,
            RTRIM(LTRIM(type)) as type,
            type_desc,
            ISNULL(LEN(a.definition)- LEN(
                REPLACE(
                a.definition, 
                CHAR(10), 
                ''''
                )
            ),0) AS LinesOfCode,
            v.name AS NameOfObject ,
            NULL as associated_table_name
            from sys.views v
            JOIN sys.schemas s ON s.schema_id = v.schema_id
            LEFT OUTER JOIN sys.all_sql_modules a ON a.OBJECT_ID = v.object_id
            WHERE v.is_ms_shipped = 0
            ) SubQuery 
                GROUP BY 
                database_name,
                schema_name,
                NameOfObject,
                type, 
                type_desc,
                associated_table_name');
        END;
    END TRY
    BEGIN CATCH
        SELECT
            host_name() as host_name,
            db_name() as database_name,
            'objectList' as module_name,
            SUBSTRING(CONVERT(nvarchar,ERROR_NUMBER()),1,254) as error_number,
            SUBSTRING(CONVERT(nvarchar,ERROR_SEVERITY()),1,254) as error_severity,
            SUBSTRING(CONVERT(nvarchar,ERROR_STATE()),1,254) as error_state,
            SUBSTRING(CONVERT(nvarchar,ERROR_MESSAGE()),1,512) as error_message;
    END CATCH

END

SELECT
    @PKEY as PKEY,
    a.*,
    @DMA_SOURCE_ID as dma_source_id,
    @DMA_MANUAL_ID as dma_manual_id
from #objectList a;

IF OBJECT_ID('tempdb..#objectList') IS NOT NULL  
   DROP TABLE #objectList;