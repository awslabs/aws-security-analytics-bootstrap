<!-- 
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: Apache-2.0 
-->

# Amazon Security Lake Example Queries

## Cloudtrail Lambda Data Events
 **NOTE:** The example queries in this file are intended to query *Cloudtrail Lambda data events*.  CloudTrail management events, S3 data events, and Lambda data events are three separate sources in Security Lake.  For more information about enabling Cloudtrail sources in Amazon Security Lake please review the official [documentation](https://docs.aws.amazon.com/security-lake/latest/userguide/internal-sources.html).

### CLOUDTRAIL LAMBDA DATA EVENTS PARTITION TESTS

**Query:** Preview first 10 rows with all fields, quick way to verify everything is setup correctly

```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_lambda_execution_1_0"
LIMIT 10;
```

### CLOUDTRAIL LAMBDA PARTITION TESTS

> **NOTE:** if there are no partition constraints (accountid, region, or eventday) then by default ALL data will be scanned this could lead to costly query, always consider using at least one partition constraint.
> 
> Note that this is the case even if you have other constraints in a query (e.g. sourceipaddress = '192.0.2.1'), only constraints using partition fields (eventday, region, accountid) will limit the amount of data scanned.

**Query:** Preview first 10 rows with all fields, limited to a single account

```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_lambda_execution_1_0"
WHERE accountid = '111122223333'
LIMIT 10;
```
**Query:** Preview first 10 rows with all fields, limited to multiple accounts

```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_lambda_execution_1_0"
WHERE accountid in ('111122223333','444455556666','123456789012')
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited to a single region

```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_lambda_execution_1_0"
WHERE region = 'us-east-1'
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited to multiple regions

```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_lambda_execution_1_0"
WHERE region in ('us-east-1','us-east-2','us-west-2')
LIMIT 10;
```

**Query:** preview first 10 rows with all fields, limited to a certain date range
> **NOTE:** eventday format is 'YYYYMMDD' as a string

```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_lambda_execution_1_0"
WHERE eventday >= '20230530'
AND eventday <= '20230631'
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited to the past 30 days (relative)

```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_lambda_execution_1_0"
WHERE eventday >= date_format(date_add('day',-30,current_timestamp), '%Y%m%d')
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited by a combination of partition constraints
> **NOTE:** narrowing the scope of the query as much as possible will improve performance and minimize cost

```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_lambda_execution_1_0"
WHERE eventday >= '20230530'
AND eventday <= '20230631'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
LIMIT 10;
```

**Query:** Query all Cloudtrail Lambda data events for a specific Lambda function named 'MyLambdaFunction'
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_lambda_execution_1_0"  
WHERE any_match(transform(resources, x -> x.uid), y -> y like '%MyLambdaFunction%')
AND eventday >= '20230530'
AND eventday <= '20230631'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2');
```