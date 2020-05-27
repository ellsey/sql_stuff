/*****************************************************************************************************************************************************************************
Repo URL:           https://github.com/ellsey/sql_stuff
Script:             create_an_error_bitmap.sql
Create Date:        2020-03-15
Author:             Luke Clark
Description:        Two queries that can be used to analyse data points and combine the results in one column. Multiple results can be applied to the same row.
                    Imagine we have 8 potential checks we want to run on a data point, the results will either be TRUE or FALSE. If we represent this like a bunch of
                    switches it will look like this:

                    Check ID:   1 2 3 4 5 6 7 8
                    Result:     - - - - - - - -

                    If we carry out checks 1 and 4 and they return TRUE we'll get:

                    Check ID:   1 2 3 4 5 6 7 8
                    Result:     T F F T F F F F

                    If we replace the TRUE with 1 and FALSE with 0 it looks like:

                    Check ID:   1 2 3 4 5 6 7 8
                    Result:     1 0 0 1 0 0 0 0

                    And if we reverse the order so it reads from right to left:

                    Check ID:   8 7 6 5 4 3 2 1
                    Result:     0 0 0 0 1 0 0 1

                    Look familiar? This is binary.

                    If we treat the checks in such a way where they are either 1 or 0 and the position is fixed then we can map the results to a binary integer (bitmap).

                    The below queries utilise bitwise SQL functions to do this. When we're done we add all the checks together which means that we will get a unique
                    integer for whatever combination of checks return true.
******************************************************************************************************************************************************************************
SUMMARY OF CHANGES
Version      Date(yyyy-mm-dd)    Author              Comments
------------ ------------------- ------------------- ----------------------------------------
1.00         2020-03-15          Luke Clark          First draft of script

******************************************************************************************************************************************************************************/

/********** PART ONE - ENCODE THE ERROR **********/
WITH E1 AS (
    SELECT "uuid", BITSHIFTLEFT(1, 0) as "error_code" FROM "SCHEMA"."YOUR_TABLE" WHERE "starting_time" < 0 AND 1=0 
), E2 AS (
    SELECT "uuid", BITSHIFTLEFT(1, 1) as "error_code" FROM "SCHEMA"."YOUR_TABLE" WHERE "customer_id" IS NULL
), E3 AS (
    SELECT "uuid", BITSHIFTLEFT(1, 2) as "error_code" FROM "SCHEMA"."YOUR_TABLE" WHERE "start_timestamp" > "end_timestamp"
), E4 AS (
    SELECT "uuid", BITSHIFTLEFT(1, 3) as "error_code" FROM "SCHEMA"."YOUR_TABLE" WHERE "test_user" != 'Customer'
), E5 AS (
    SELECT "uuid", BITSHIFTLEFT(1, 4) as "error_code" FROM "SCHEMA"."YOUR_TABLE" WHERE "cir_time" > (60000*30) AND 1=0
), E6 AS (
    SELECT "uuid", BITSHIFTLEFT(1, 5) as "error_code" FROM "SCHEMA"."YOUR_TABLE" WHERE "country" IS NULL
), E7 AS (
    SELECT "uuid", BITSHIFTLEFT(1, 6) as "error_code" FROM "SCHEMA"."YOUR_TABLE" WHERE "content_source" IS NULL
), E8 AS (
    SELECT "uuid", BITSHIFTLEFT(1, 7) as "error_code" FROM "SCHEMA"."YOUR_TABLE" WHERE "device_vendor" IS NULL
), E_ALL_PT1 AS (
    SELECT * FROM E1
    UNION SELECT * FROM E2
    UNION SELECT * FROM E3
    UNION SELECT * FROM E4
    UNION SELECT * FROM E5
    UNION SELECT * FROM E6
    UNION SELECT * FROM E7
    UNION SELECT * FROM E8
), E_ALL_PT2 AS (
SELECT
    "uuid", SUM("error_code") AS "error_bitmap"
FROM E_ALL_PT1
GROUP BY 1
)
SELECT
    st."uuid"
    ,st.* -- add in the source columns you want from your source table
    ,error."error_bitmap"
FROM "SCHEMA"."YOUR_TABLE" st LEFT JOIN E_ALL_PT2 error on st."uuid" = error."uuid"
;



/********** PART TWO - DECODE THE ERROR **********/	
WITH descr as (
	SELECT 1 AS "error_bit", 'Playback - Negative startup time - startup error' as "description"  
    UNION SELECT 2 AS "error_bit", 'Customer - Account ID not defined' as "description"
    UNION SELECT 3 AS "error_bit", 'Playback - Start time after end time' as "description"
    UNION SELECT 4 AS "error_bit", 'Customer - Test Customer' as "description"
    UNION SELECT 5 AS "error_bit", 'Playback - CIR greater than 30mins' as "description"
    UNION SELECT 6 AS "error_bit", 'Customer - Country not defined' as "description"
    UNION SELECT 7 AS "error_bit", 'Content - Article not found' as "description"
    UNION SELECT 8 AS "error_bit", 'Device - User Agent not defined' as "description"
) 
SELECT "description", COUNT(*) AS "num" FROM "SCHEMA"."YOUR_TABLE"
CROSS JOIN descr 
WHERE BITAND("error_bitmap", BITSHIFTLEFT(1, "error_bit" - 1)) > 0
GROUP BY 1,2
ORDER BY 1
;
    