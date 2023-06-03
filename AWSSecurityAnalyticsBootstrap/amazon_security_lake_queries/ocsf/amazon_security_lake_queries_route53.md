<!-- 
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: Apache-2.0 
-->

# Amazon Security Lake Demo Queries

## Route53

### PREVIEW TABLE

**Query:** Preview first 10 rows with all fields, quick way to verify everything is setup correctly
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_route53"
LIMIT 10;
```

### ROUTE 53 PARTITION TESTS 
> **NOTE:** if there are no partition constraints (accountid, region, or eventday) then by default ALL data will be scanned this could lead to costly query, always consider using at least one partition constraint.
> 
> Note that this is the case even if you have other constraints in a query (e.g. sourceipaddress = '192.0.2.1'), only constraints using partition fields (eventday, region, accountid) will limit the amount of data scanned.


**Query:** Preview first 10 rows with all fields, limited to a single account
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_route53"
WHERE accountid = '111122223333'
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited to multiple accounts
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_route53"
WHERE accountid in ('111122223333','444455556666','123456789012')
LIMIT 10;
```


**Query:** Preview first 10 rows with all fields, limited to a single region
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_route53"
WHERE region = 'us-east-1'
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited to multiple regions
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_route53"
WHERE region in ('us-east-1','us-east-2','us-west-2')
LIMIT 10;
```

**Query:** preview first 10 rows with all fields, limited to a certain date range
> NOTE: eventday format is 'YYYYMMDD' as a string
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_route53"
WHERE eventday >= '20230530'
AND eventday <= '20230631'
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited to the past 30 days (relative)
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_route53"
WHERE eventday >= date_format(date_add('day',-30,current_timestamp), '%Y%m%d')
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited by a combination of partition constraints
> NOTE: narrowing the scope of the query as much as possible will improve performance and minimize cost

```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_route53"
WHERE eventday >= '20230530'
AND eventday <= '20230631'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
LIMIT 10;
```

### ROUTE53 ANALYSIS EXAMPLES

**Query:** Sort queries by the number of isntances that requested each hostname

```
SELECT  query.hostname, query.type, cardinality(array_distinct(filter(array_agg(src_endpoint), q -> q.instance_uid IS NOT NULL))) as instance_count, array_distinct(filter(array_agg(src_endpoint), q -> q.instance_uid IS NOT NULL)) as instances
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_route53"
WHERE eventday >= '20230530'
AND eventday <= '20230631'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY query.hostname, query.type
ORDER by instance_count DESC;
```

**Query:** Sort queries by the number of queries for each each hostname

```
SELECT  query.hostname, query.type, count(*) as query_count FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_route53"
WHERE eventday >= '20230530'
AND eventday <= '20230631'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY query.hostname, query.type
ORDER BY query_count DESC;
```

**Query:** Summary with count of each time an A record type of a hostname was queried
```
SELECT  query.hostname, query.type, count(*) as query_count FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_route53"
WHERE query.type = 'A'
AND eventday >= '20230530'
AND eventday <= '20230631'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY query.hostname, query.type
ORDER BY query_count DESC;
```

**Query:** Summary with count of each time an A record type of a hostname was queried. Split out TLD and SLD (note: doesn't properly handle TLDs containing a '.' (e.g. .com.br)

```
SELECT element_at(split(query.hostname,'.'),-2) AS tld, 
        element_at(split(query.hostname,'.'),-3) AS sld, 
        query.hostname, query.type, 
        count(*) AS query_count
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_route53"
WHERE query.type = 'A'
AND eventday >= '20230530'
AND eventday <= '20230631'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY  query.hostname, query.type
ORDER BY  query_count DESC;
```

**Query:** Get records that that resolve to a specific IP (e.g., 203.0.113.2)

```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_route53"
WHERE contains(transform(answers, x-> x.rdata), '203.0.113.2')
AND eventday >= '20230530'
AND eventday <= '20230631'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2');
```
