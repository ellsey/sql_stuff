/*****************************************************************************************************************************************************************************
Repo URL:           https://github.com/ellsey/sql_stuff
Script:             summarise_on_changes.sql
Create Date:        2020-05-27
Author:             Luke Clark
Description:        Fairly useful bit of SQL for deduplicating / summarising / collapsing large datasets by working out the changes and adding in effective dates. You'll end
                    up with a 'slowly changing dimension' (SCD) sometimes called a Type 2 table.

                    Method

                    part0 - take event/transaction data and LEAD the event timestamp to get an effective until date. In case of duplicates we add in a ROW_NUMBER so we can
                    filter out all but where = 1. Notice ROW_NUMBER() is partitioned by all the attributes we're looking at - this is so we only get rid of rows where they are 
                    all identical.

                    part1 - lag each attribute and build a big case statement where if any attribute is different to its lagged self then flag with a 1 else 0 end. This 
                    gives us a 'change_flag' which tells us whenever something changes in these attributes.

                    part2 - create a running total of the change flag which we can use as a 'pseudo_id'

                    final select - group by your ID, your attributes, and your pseudo ID taking care to take the MIN and MAX of the effective dates to get the true
                    effective dates

                    Some example usecases I've come across before:

                    1 - Deduplicating huge event / transaction tables
                    2 - Building sessions from web analytics data (effective dates become session start/end)
                    3 - Creating journeys from telematics data (effective dates become journey start/end)
                    4 - Defining a customer history dimension

                    You can use this method anywhere, simply adjust the logic used to create your 'change flag'

                    Notes
                    1 It's important you are strict and carry out the operations on all the columns you're bringing through otherwise it won't work. Simple Rule: if it's
                    in your GROUP BY it needs to be LAGGED
                    2 Depending on your database you might need to be careful with NULL values as they may return NULL instead of TRUE. Use COALESCE to be sure.

******************************************************************************************************************************************************************************
SUMMARY OF CHANGES
Version      Date(yyyy-mm-dd)    Author              Comments
------------ ------------------- ------------------- ----------------------------------------
1.00         2020-05-27          Luke Clark          First draft of script

******************************************************************************************************************************************************************************/

WITH part0 AS (
    SELECT
        "customer_id"
        ,"some_attribute"
        ,"some_other_attribute"
        ,"one_final_attribute"
        ,"event_timestamp" AS "effective_from"
        ,LEAD("event_timestamp") OVER (PARTITION BY "customer_id" ORDER BY "event_timestamp" ASC) AS "effective_until"
        ,ROW_NUMBER() OVER (PARTITION BY "customer_id", "some_attribute", "some_other_attribute" ,"one_final_attribute" ORDER BY "event_timestamp" ASC) AS "dup_id"
    FROM "DATABASE"."SCHEMA"."YOUR_SOURCE_EVENT_TABLE"
), part1 AS (
    SELECT
        "customer_id"
        ,"some_attribute"
        ,"some_other_attribute"
        ,"one_final_attribute"
        ,"effective_from"
        ,"effective_until"
        ,CASE
            WHEN "some_attribute" <> LAG("some_attribute",1) OVER (PARTITION BY "customer_id" ORDER BY "effective_from", "effective_until")
                OR "some_other_attribute" <> LAG("some_other_attribute",1) OVER (PARTITION BY "customer_id" ORDER BY "effective_from", "effective_until")
                    OR "one_final_attribute" <> LAG("one_final_attribute",1) OVER (PARTITION BY "customer_id" ORDER BY "effective_from", "effective_until")
                        THEN 1
            ELSE 0
        END AS "change_flag"
    FROM part0
    WHERE 
), part2 AS (
    SELECT
        "customer_id"
        ,"some_attribute"
        ,"some_other_attribute"
        ,"one_final_attribute"
        ,"effective_from"
        ,"effective_until"
        ,"change_flag"
        ,SUM("change_flag") OVER (PARTITION BY "customer_id" ORDER BY "effective_from", "effective_until") AS "pseudo_id"
    FROM part1
)
SELECT
    "customer_id"
    ,"some_attribute"
    ,"some_other_attribute"
    ,"one_final_attribute"
    ,"pseudo_id"
    ,MIN("effective_from") AS "effective_from"
    ,MAX("effective_until") AS "effective_until"
FROM part2
GROUP BY 1,2,3,4,5
ORDER BY 6,7
;
    