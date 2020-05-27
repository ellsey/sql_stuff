/*****************************************************************************************************************************************************************************
Repo URL:           https://github.com/ellsey/sql_stuff
Script:             information_schema_magic.sql
Create Date:        2020-05-27
Author:             Luke Clark
Description:        Some example queries that use the information schema to dynamically generate SQL statements. Can be placed within dataframes and executed within a Python
                    script.

                    Key skill here is to construct a statement as a string and then concatenate the values you want from the information schema.

                    Notes
                    So far every database I've worked with has differences in their information schema so worth spending some time to get to grips with them before jumping
                    into something like this.

******************************************************************************************************************************************************************************
SUMMARY OF CHANGES
Version      Date(yyyy-mm-dd)    Author              Comments
------------ ------------------- ------------------- ----------------------------------------
1.00         2020-05-27          Luke Clark          First draft of script

******************************************************************************************************************************************************************************/

/****** EXAMPLE 1 - GENERATE A BUNCH OF QUERIES TO CARRY OUT CHECKS ON A TABLE ******/

-- NB this one has a UNION stuck on the end so you can run them all at once. Will need to remove the final UNION before running.
SELECT
'SELECT '''||COLUMN_NAME||''' AS column_name, SUM(CASE WHEN "'||COLUMN_NAME||'" IS NULL THEN 1 ELSE 0 END) AS total_nulls, COUNT (*) AS total_rows, total_nulls / total_rows AS null_ratio,
COUNT (DISTINCT "'||COLUMN_NAME||'") AS distinct_values FROM "DATABASE"."SCHEMA"."YOUR_TABLE" GROUP BY 1 UNION' AS SQL
FROM "PRD_UAT"."INFORMATION_SCHEMA"."COLUMNS"
WHERE "TABLE_NAME" = 'YOUR_TABLE'
;


/****** EXAMPLE 2 - DAILY GARBAGE COLLECTOR ******/

-- this is using Snowflake information schema. Idea here is to generate a bunch of statements to drop/truncate all tables in a STAGING schema.
-- once you've got the code in a table you can load into a python dataframe and execute the SQL
DROP TABLE IF EXISTS "DATABASE"."SCHEMA"."generate_dynamic_sql"
;
CREATE TABLE "DATABASE"."SCHEMA"."generate_dynamic_sql" AS
WITH T1 AS (
    SELECT "TABLE_NAME", 
           "TABLE_SCHEMA",
           "TABLE_CATALOG"
    FROM "DATABASE"."INFORMATION_SCHEMA"."TABLES"
    WHERE "TABLE_SCHEMA" = 'SCHEMA'
)
SELECT
    "TABLE_NAME",
    "TABLE_SCHEMA",
    'TRUNCATE TABLE IF EXISTS' || '"' || "TABLE_CATALOG" || '".' || '"' || "TABLE_SCHEMA" || '"."' || "TABLE_NAME" || '";' AS drop_code
FROM T1
;