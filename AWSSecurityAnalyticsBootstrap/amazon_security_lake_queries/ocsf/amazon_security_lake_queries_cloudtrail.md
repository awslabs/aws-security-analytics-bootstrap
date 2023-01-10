<!-- 
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: Apache-2.0 
-->

# Amazon Security Lake Demo Queries

## Cloudtrail

### PREVIEW CLOUDTRAIL TABLE

**Query:** Preview first 10 rows with all fields, quick way to verify everything is setup correctly

```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail"
LIMIT 10; 
```

### CLOUDTRAIL PARTITION TESTS 
> **NOTE:** if there are no partition constraints (accountid, region, or eventhour) then by default ALL data will be scanned this could lead to costly query, always consider using at least one partition constraint.
> 
> Note that this is the case even if you have other constraints in a query (e.g. sourceipaddress = '192.0.2.1'), only constraints using partition fields (eventhour, region, accountid) will limit the amount of data scanned.

**Query:** Preview first 10 rows with all fields, limited to a single account
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail"
WHERE accountid = '111122223333'
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited to multiple accounts
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail"
WHERE accountid in ('111122223333','444455556666','123456789012')
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited to a single region
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail"
WHERE region = 'us-east-1'
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited to multiple regions
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail"
WHERE region in ('us-east-1','us-east-2','us-west-2')
LIMIT 10;
```

**Query:** preview first 10 rows with all fields, limited to a certain date range
> NOTE: eventhour format is 'YYYYMMDDHH' as a string
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail"
WHERE eventhour >= '2022110100'
AND eventhour <= '2022110700'
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited to the past 30 days (relative)
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail"
WHERE eventhour >= date_format(date_add('day',-30,current_timestamp), '%Y%m%d%H')
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited by a combination of partition constraints
> NOTE: narrowing the scope of the query as much as possible will improve performance and minimize cost

```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail"
WHERE eventhour >= '2022110100'
AND eventhour <= '2022110700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
LIMIT 10;
```

### CLOUDTRAIL ANALYSIS EXAMPLES
> NOTE: default partition constraints have been provided for each query, be sure to add the appropriate partition constraints to the WHERE clause as shown in the section above

> DEFAULT partition constraints: 
```
    WHERE eventhour >= '2022110100'
    AND eventhour <= '2022110700'
    AND accountid = '111122223333'
    AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
```
> Be sure to modify or remove these to fit the scope of your intended analysis


**Query:** Summary of event counts by Region (e.g. where is the most activity)
```
SELECT region, count(*) as eventcount FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail"
WHERE eventhour >= '2022110100'
AND eventhour <= '2022110700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY region
ORDER BY eventcount DESC
```

**Query:** Summary of event count by Region and EventName, ordered by event count (descending) for each region.  This is a quick way to identify top cloudtrail eventnames seen in each region

```
SELECT region, api.operation, count(*) as operation_count FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail"
WHERE eventhour >= '2022110100'
AND eventhour <= '2022110700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY region, api.operation
ORDER BY region, operation_count DESC
```

**Query:** User login summary, via AssumeRole or ConsoleLogin includes a list of all source IPs for each user
```
SELECT  identity.user.uuid, api.operation, array_agg(DISTINCT(src_endpoint.ip) ORDER BY src_endpoint.ip) AS sourceips FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail"
WHERE identity.user.uuid IS NOT NULL
AND (api.operation = 'AssumeRole' OR api.operation = 'ConsoleLogin')
AND eventhour >= '2022110100'
AND eventhour <= '2022110700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY identity.user.uuid, api.operation
ORDER BY api.operation
```

**Query:**  User login summary, via AssumeRole or ConsoleLogin includes a list of all source IPs for each user

> NOTE: This query is simlar to the quere above, except it uses the normalized OCSF activityid for login activity (1) rather than explitly searching for login operation names.

```
SELECT  identity.user.uuid, api.operation, array_agg(DISTINCT(src_endpoint.ip) ORDER BY src_endpoint.ip) AS sourceips FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail"
WHERE activity_id = 1
AND eventhour >= '2022110100'
AND eventhour <= '2022110700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY identity.user.uuid, api.operation
ORDER BY api.operation
```


**Query:** User Activity Summary: filter high volume read-only GET/LIST/DECRIBE calls

```
SELECT identity.user.uuid, array_agg(DISTINCT(api.operation)) AS operations,
	array_agg(DISTINCT(src_endpoint.ip) ORDER BY src_endpoint.ip) AS sourceips,
	array_agg(DISTINCT(http_request.user_agent) ORDER BY http_request.user_agent) AS user_agents FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail"
WHERE api.operation <> 'AssumeRole'
AND api.operation NOT LIKE 'Get%'
AND api.operation NOT LIKE 'List%'
AND api.operation NOT LIKE 'Describe%'
AND eventhour >= '2022110100'
AND eventhour <= '2022110700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY identity.user.uuid
```

**Query:** User Activity Summary, including username: filter high volume read-only GET/LIST/DECRIBE calls
> NOTE: this query is similar to the one above, but will include the ARN or the username (for IAM Users) of the principal 

```
SELECT identity.user.uuid, identity.user.name,
	array_agg(DISTINCT(api.operation) ORDER BY api.operation) AS operations,
	array_agg(DISTINCT(src_endpoint.ip) ORDER BY src_endpoint.ip) AS sourceips,
	array_agg(DISTINCT(http_request.user_agent) ORDER BY http_request.user_agent) AS user_agents FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail"
WHERE api.operation <> 'AssumeRole'
AND api.operation NOT LIKE 'Get%'
AND api.operation NOT LIKE 'List%'
AND api.operation NOT LIKE 'Describe%'
AND eventhour >= '2022110100'
AND eventhour <= '2022110700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY identity.user.uuid, identity.user.uid, identity.user.name
```

**Query:** IAM change summary: Filter read-only GET/LIST/DESCRIBE and Filter unsuccessful calls

```
SELECT time, identity.user.uuid, identity.user.name, api.operation, unmapped['requestParameters'] AS request_parameters
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail"
WHERE api.service.name = 'iam.amazonaws.com'
AND api.operation NOT LIKE 'Get%'
AND api.operation NOT LIKE 'List%'
AND api.operation NOT LIKE 'Describe%'
AND api.response.error IS NULL
AND eventhour >= '2022110100'
AND eventhour <= '2022110700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
ORDER BY accountid, time
```

**Query:** Access Key creations with extract of username and keyid. Filter unsuccessful calls

```
SELECT time, identity.user.uuid, identity.user.name, api.operation,
	JSON_EXTRACT_SCALAR(JSON_EXTRACT(unmapped['responseElements'], '$.accessKey'), '$.userName') AS user_name,
	JSON_EXTRACT_SCALAR(JSON_EXTRACT(unmapped['responseElements'], '$.accessKey'), '$.accessKeyId') AS access_key
	FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail"
WHERE api.operation = 'CreateAccessKey'
AND api.response.error IS NULL
AND eventhour >= '2022110100'
AND eventhour <= '2022110700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
ORDER BY accountid, time
```

**Query:** Password changes with extract of username. Filter unsuccessful calls

```
SELECT time, identity.user.uuid, identity.user.name, api.operation,
	JSON_EXTRACT_SCALAR(unmapped['requestParameters'] , '$.userName') AS "username with password modified"
	FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail"
WHERE api.operation IN ('UpdateLoginProfile', 'CreateLoginProfile')
AND api.response.error IS NULL
AND eventhour >= '2022110100'
AND eventhour <= '2022110700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
ORDER BY accountid, time
```

**Query:** Identify API events made from a public IP (i.e. a non-RFC1918 source IP address from a publicly routed address).  Useful to filter internal API calls.

> NOTE: this is an example of the new IPADDRESS data type added in Athena engine v2 and IP Address contains function added in the Athena engine v3.  Be sure that you've [enabled Athena engine v3](https://aws.amazon.com/blogs/big-data/upgrade-to-athena-engine-version-3-to-increase-query-performance-and-access-more-analytics-features/)

```
SELECT *
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail"
WHERE NOT contains('10.0.0.0/8', CAST(src_endpoint.ip AS IPADDRESS))
AND NOT contains('172.16.0.0/12', CAST(src_endpoint.ip AS IPADDRESS))
AND NOT contains('192.168.0.0/16', CAST(src_endpoint.ip AS IPADDRESS))
AND eventhour >= '2022110100'
AND eventhour <= '2022110700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
```
