/*
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: Apache-2.0
*/

-- PREVIEW TABLE
-- preview first 10 rows with all fields, quick way to verify everything is setup correctly

SELECT * from cloudtrail
LIMIT 10;

-- PARTITION TESTS 
/*   NOTE: if there are no constraints a partition (account, region, or date) then by default ALL data will be scanned
           this could lead to costly query, always consider using at least one partition constraint.

           Note that this is the case even if you have other constraints in a query (e.g. sourceipaddress = '192.0.2.1'),
           only constraints using partition fields (date_partition, region_partition, account_partition)
           will limit the amount of data scanned.
*/        

-- preview first 10 rows with all fields, limited to a single account
SELECT * from cloudtrail
WHERE account_partition = '111122223333'
LIMIT 10;

-- preview first 10 rows with all fields, limited to multiple accounts
SELECT * from cloudtrail
WHERE account_partition in ('111122223333','444455556666','123456789012')
LIMIT 10;

-- preview first 10 rows with all fields, limited to a single region
SELECT * from cloudtrail
WHERE region_partition = 'us-east-1'
LIMIT 10;

-- preview first 10 rows with all fields, limited to multiple regions
SELECT * from cloudtrail
WHERE region_partition in ('us-east-1','us-east-2','us-west-2')
LIMIT 10;

-- NOTE: date_partition format is 'YYYY/MM/DD' as a string
-- preview first 10 rows with all fields, limited to a certain date range
SELECT * from cloudtrail
WHERE date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
LIMIT 10;

-- preview first 10 rows with all fields, limited to the past 30 days (relative)
SELECT * from cloudtrail
WHERE date_partition >= date_format(date_add('day',-30,current_timestamp), '%Y/%m/%d')
LIMIT 10;

-- preview first 10 rows with all fields, limited by a combination partition constraints
-- NOTE: narrowing the scope of the query as much as possible will improve performance and minimize cost
SELECT * from cloudtrail
WHERE date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
AND account_partition = '111122223333'
AND region_partition in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
LIMIT 10;

-- ANALYSIS EXAMPLES
-- NOTE: default partition constraints have been provided for each query, 
--       be sure to add the appropriate partition constraints to the WHERE clause as shown above
/*  
    DEFAULT partition constraints: 
        WHERE date_partition >= '2021/07/01'
        AND date_partition <= '2021/07/31'
        AND account_partition = '111122223333'
        AND region_partition in ('us-east-1','us-east-2','us-west-2', 'us-west-2')

    Be sure to modify or remove these to fit the scope of your intended analysis
*/

-- Summary of event counts by Region (e.g. where is the most activity)
SELECT region_partition, count(*) as eventcount FROM cloudtrail
WHERE date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
AND account_partition = '111122223333'
AND region_partition in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY region_partition
ORDER BY eventcount DESC

-- Summary of event count by Region and EventName, ordered by event count (descending) for each region
--   Quick way to identify top EventNames seen in each region
SELECT region_partition, eventname, count(*) as eventcount FROM cloudtrail
WHERE date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
AND account_partition = '111122223333'
AND region_partition in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY region_partition, eventname
ORDER BY region_partition, eventcount DESC

-- User login summary, via AssumeRole or ConsoleLogin
--   includes a list of all source IPs for each user
SELECT  useridentity.arn, eventname, array_agg(DISTINCT(sourceipaddress) ORDER BY sourceipaddress) AS sourceips FROM cloudtrail
WHERE useridentity.arn IS NOT NULL
AND (eventname = 'AssumeRole' OR eventname = 'ConsoleLogin')
AND date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
AND account_partition = '111122223333'
AND region_partition in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY useridentity.arn, eventname
ORDER BY eventname

-- User Activity Summary
-- filter high volume read-only GET/LIST/DECRIBE calls
SELECT useridentity.arn, array_agg(DISTINCT(eventname)) AS eventnames,
	array_agg(DISTINCT(sourceipaddress) ORDER BY sourceipaddress) AS sourceips,
	array_agg(DISTINCT(useragent) ORDER BY useragent) AS useragents FROM cloudtrail
WHERE eventname <> 'AssumeRole'
AND eventname NOT LIKE 'Get%'
AND eventname NOT LIKE 'List%'
AND eventname NOT LIKE 'Describe%'
AND date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
AND account_partition = '111122223333'
AND region_partition in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY useridentity.arn

-- User Activity Summary, including username
-- filter high volume read-only GET/LIST/DECRIBE calls
-- same as above, but will include the ARN or the username (for IAM Users) of the principal 
SELECT useridentity.arn, useridentity.username,
	array_agg(DISTINCT(eventname) ORDER BY eventname) AS eventnames,
	array_agg(DISTINCT(sourceipaddress) ORDER BY sourceipaddress) AS sourceips,
	array_agg(DISTINCT(useragent) ORDER BY useragent) AS useragents FROM cloudtrail
WHERE eventname <> 'AssumeRole'
AND eventname NOT LIKE 'Get%'
AND eventname NOT LIKE 'List%'
AND eventname NOT LIKE 'Describe%'
AND date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
AND account_partition = '111122223333'
AND region_partition in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY useridentity.arn, useridentity.principalid, useridentity.username

-- IAM change summary
-- * filter read-only GET/LIST/DESCRIBE
-- * filter unsuccessful calls
SELECT eventtime, useridentity.arn, useridentity.username, eventname, requestparameters 
FROM cloudtrail
WHERE eventsource = 'iam.amazonaws.com'
AND eventname NOT LIKE 'Get%'
AND eventname NOT LIKE 'List%'
AND eventname NOT LIKE 'Describe%'
AND errorcode IS NULL
AND date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
AND account_partition = '111122223333'
AND region_partition in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
ORDER BY account_partition, eventtime

-- Access Key creations with extract of username and keyid
-- * filter unsuccessful calls
SELECT eventtime, useridentity.arn, useridentity.username, eventname,
	JSON_EXTRACT_SCALAR(JSON_EXTRACT(responseelements, '$.accessKey'), '$.userName') AS userName,
	JSON_EXTRACT_SCALAR(JSON_EXTRACT(responseelements, '$.accessKey'), '$.accessKeyId') AS accessKey
	FROM cloudtrail
WHERE eventname = 'CreateAccessKey'
AND errorcode IS NULL
AND date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
AND account_partition = '111122223333'
AND region_partition in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
ORDER BY account_partition, eventtime

-- Password changes with extract of username
-- * filter unsuccessful calls
SELECT eventtime, useridentity.arn, useridentity.username, eventname,
	JSON_EXTRACT_SCALAR(requestparameters, '$.userName') AS "username with password modified"
	FROM cloudtrail
WHERE eventname IN ('UpdateLoginProfile', 'CreateLoginProfile')
AND errorcode IS NULL
AND date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
AND account_partition = '111122223333'
AND region_partition in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
ORDER BY account_partition, eventtime

-- Identify API events made from a public IP (i.e. a non-RFC1918 source IP address)
-- NOTE: this is an example of using the new IPADDRESS data type, as string a string comparison would correctly compare IP addresses
SELECT *
FROM cloudtrail
WHERE   regexp_like(sourceipaddress, '^\d')
AND NOT ( (CAST(sourceipaddress AS IPADDRESS) > IPADDRESS '10.0.0.0'
AND CAST(sourceipaddress AS IPADDRESS) < IPADDRESS '10.255.255.255')
OR (CAST(sourceipaddress AS IPADDRESS) > IPADDRESS '172.16.0.0'
AND CAST(sourceipaddress AS IPADDRESS) < IPADDRESS '172.31.255.255')
OR (CAST(sourceipaddress AS IPADDRESS) > IPADDRESS '192.168.0.0'
AND CAST(sourceipaddress AS IPADDRESS) < IPADDRESS '192.168.255.255'))
AND date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
AND account_partition = '111122223333'
AND region_partition in ('us-east-1','us-east-2','us-west-2', 'us-west-2')

-- Create optimized ORC columnar format table for a single account and region for the past 90 days
-- NOTE: single query limit is 100 partitions, to add additional accounts, regions, or days use the following INSERT INTO method
-- Reference: https://docs.aws.amazon.com/athena/latest/ug/ctas-insert-into.html
CREATE TABLE cloudtrail_orc
WITH (format = 'ORC', orc_compression = 'SNAPPY', partitioned_by = ARRAY['account_partition','region_partition','date_partition'] ) AS
SELECT eventversion,
         useridentity,
         eventtime,
         eventsource,
         eventname,
         awsregion,
         sourceipaddress,
         useragent,
         errorcode,
         errormessage,
         requestparameters,
         responseelements,
         additionaleventdata,
         requestid,
         eventid,
         resources,
         eventtype,
         apiversion,
         readonly,
         recipientaccountid,
         serviceeventdetails,
         sharedeventid,
         vpcendpointid,
         account_partition,
         region_partition,
         date_partition
FROM cloudtrail
WHERE account_partition = '111122223333' 
AND region_partition = 'us-east-1'
AND date_partition >= date_format(date_add('day',-90,current_timestamp), '%Y/%m/%d')

-- Add optimized ORC columnar format table for a single account and region for the past 90 days
-- NOTE: single query limit is 100 partitions, to add additional accounts, regions, or days keep using this INSERT INTO method
-- Reference: https://docs.aws.amazon.com/athena/latest/ug/ctas-insert-into.html
INSERT INTO cloudtrail_orc
SELECT eventversion,
         useridentity,
         eventtime,
         eventsource,
         eventname,
         awsregion,
         sourceipaddress,
         useragent,
         errorcode,
         errormessage,
         requestparameters,
         responseelements,
         additionaleventdata,
         requestid,
         eventid,
         resources,
         eventtype,
         apiversion,
         readonly,
         recipientaccountid,
         serviceeventdetails,
         sharedeventid,
         vpcendpointid,
         account_partition,
         region_partition,
         date_partition
FROM cloudtrail
WHERE account_partition = '111122223333' 
AND region_partition = 'us-east-2'
AND date_partition >= date_format(date_add('day',-90,current_timestamp), '%Y/%m/%d')