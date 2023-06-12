<!-- 
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: Apache-2.0 
-->

# Amazon Security Lake Example Queries

## VPC Flow

### PREVIEW TABLE

**Query:** Preview first 10 rows with all fields, quick way to verify everything is setup correctly

```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow_1_0"
LIMIT 10;
```

### VPCFLOW PARTITION TESTS 
> **NOTE:** if there are no partition constraints (accountid, region, or eventday) then by default ALL data will be scanned this could lead to costly query, always consider using at least one partition constraint.
> 
> Note that this is the case even if you have other constraints in a query (e.g. sourceipaddress = '192.0.2.1'), only constraints using partition fields (eventday, region, accountid) will limit the amount of data scanned.

**Query:** Preview first 10 rows with all fields, limited to a single account

```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow_1_0"
WHERE accountid = '111122223333'
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited to multiple accounts
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow_1_0"
WHERE accountid in ('111122223333','444455556666','123456789012')
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited to a single region
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow_1_0"
WHERE region = 'us-east-1'
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited to multiple regions
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow_1_0"
WHERE region in ('us-east-1','us-east-2','us-west-2')
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited to a certain date range
> NOTE: eventday format is 'YYYYMMDD' as a string

SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow_1_0"
WHERE eventday >= '20230530'
AND eventday <= '20230631'
LIMIT 10;

**Query:** Preview first 10 rows with all fields, limited to the past 30 days (relative)
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow_1_0"
WHERE eventday >= date_format(date_add('day',-30,current_timestamp), '%Y%m%d')
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited by a combination partition constraints

> NOTE: narrowing the scope of the query as much as possible will improve performance and minimize cost
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow_1_0"
WHERE eventday >= '20230530'
AND eventday <= '20230631'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
LIMIT 10;
```
### VPC FLOW ANALYSIS EXAMPLES

> NOTE: default partition constraints have been provided for each query, be sure to add the appropriate partition constraints to the WHERE clause as shown in the section above

> DEFAULT partition constraints: 
```
    WHERE eventday >= '20230530'
    AND eventday <= '20230631'
    AND accountid = '111122223333'
    AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
```

**Query:** Get list source/destination IP pairs ordered by the number of records 
```
SELECT region, src_endpoint.ip as src_ip, dst_endpoint.ip as dst_ip, count(*) as record_count FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow_1_0"
WHERE eventday >= '20230530'
AND eventday <= '20230631'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY region, src_endpoint.ip, dst_endpoint.ip
ORDER BY record_count DESC
```

**Query:** Get a summary of records between a given source/destination IP pair, ordered by the total number of bytes

```
SELECT region, src_endpoint.ip as src_ip, dst_endpoint.ip as dst_ip, sum(traffic.bytes) as byte_count FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow_1_0"
WHERE (src_endpoint.ip = '192.0.2.1' OR dst_endpoint.ip = '192.0.2.1')
AND (src_endpoint.ip = '203.0.113.2' OR dst_endpoint.ip = '203.0.113.2')
AND eventday >= '20230530'
AND eventday <= '20230631'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY region, dst_endpoint.instance_uid, src_endpoint.ip, dst_endpoint.ip
ORDER BY byte_count DESC
```

**Query:** Get a summary of the number of bytes sent from port 443 limited to a single instance
> NOTE: for remote IPs this represents the amount data downloaded from port 443 by the instance, for instance IPs this represents the amount data downloaded by remost hosts from the instance on port 443

```
SELECT region, dst_endpoint.instance_uid as dst_instance_id, src_endpoint.ip as src_ip, src_endpoint.port as src_port, dst_endpoint.ip as dst_ip, sum(traffic.bytes) as byte_count FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow_1_0"
WHERE dst_endpoint.instance_uid = 'i-000000000000000'
AND src_endpoint.port = 443
AND eventday >= '20230530'
AND eventday <= '20230631'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY region, dst_endpoint.instance_uid, src_endpoint.ip, src_endpoint.port, dst_endpoint.ip
ORDER BY byte_count DESC
```

**Query:** Get a summary with the number of bytes for each src_ip,src_port,dst_ip,dst_port quad across all records to or from a specific IP

```
SELECT src_endpoint.ip as src_ip, dst_endpoint.ip as dst_ip, src_endpoint.port as src_port, dst_endpoint.port as dst_port, sum(traffic.bytes) as byte_count FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow_1_0"
WHERE (src_endpoint.ip = '192.0.2.1' OR dst_endpoint.ip = '192.0.2.1')
AND eventday >= '20230530'
AND eventday <= '20230631'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY src_endpoint.ip, dst_endpoint.ip, src_endpoint.port, dst_endpoint.port
ORDER BY byte_count DESC
```

**Query:** Get all flow records between two IPs showing connection_info.direction
```
SELECT from_unixtime(start_time/1000) AS start_time,
from_unixtime(end_time/1000) AS end_time,
src_endpoint.ip,
dst_endpoint.ip,
src_endpoint.port,
dst_endpoint.port,
traffic.packets,
traffic.bytes,
connection_info.direction,
activity_name
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow_1_0"
WHERE (src_endpoint.ip = '192.0.2.1'
AND dst_endpoint.ip = '192.0.2.254')
OR (src_endpoint.ip = '192.0.2.254'
AND dst_endpoint.ip = '192.0.2.1')
ORDER BY start_time ASC
```

**Query:** List when source ips were first seen / last seen with a summary of destination ip/instances/ports
```
SELECT src_endpoint.ip,
         from_unixtime(min(start_time)/1000) AS first_seen,
         from_unixtime(max(end_time)/1000) AS last_seen,
         array_agg(DISTINCT(dst_endpoint.ip)),
         array_agg(DISTINCT(dst_endpoint.instance_uid)),
         array_agg(DISTINCT(dst_endpoint.port))
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow_1_0"
WHERE dst_endpoint.port < 32768 -- skip ephemeral ports, since we're looking for inbound connections to service ports
AND eventday >= '20230530'
AND eventday <= '20230631'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY src_endpoint.ip
ORDER by first_seen ASC
```


**Query:** Transfer Report on Top 10 Internal IPs with large transfers, limited to source addresses in network 192.0.2.0/24

```
SELECT vpcflow.eventday, vpcflow.src_endpoint.ip as src_endpoint_ip, vpcflow.dst_endpoint.ip as dst_endpoint_ip, sum(vpcflow.traffic.bytes) as byte_count
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow_1_0" as vpcflow
INNER JOIN (SELECT src_endpoint.ip as src_endpoint_ip, sum(traffic.bytes) as byte_count FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow_1_0" 
WHERE src_endpoint.ip <> '-'
AND contains('192.0.2.0/24', cast(src_endpoint.ip as IPADDRESS))
AND eventday >= '20230530'
AND eventday <= '20230631'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY region, dst_endpoint.instance_uid, src_endpoint.ip, dst_endpoint.ip, dst_endpoint.port
ORDER BY byte_count DESC
LIMIT 10 ) as top_n 
ON top_n.src_endpoint_ip = vpcflow.src_endpoint.ip
WHERE eventday >= '20230530'
AND eventday <= '20230631'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY vpcflow.eventday, vpcflow.src_endpoint.ip, vpcflow.dst_endpoint.ip
ORDER BY vpcflow.eventday ASC, vpcflow.src_endpoint.ip ASC, vpcflow.dst_endpoint.ip ASC, byte_count DESC
```

**Query:** Search for traffic between a private (RFC1918) IP address and a public (non-RFC1918) IP address
> NOTE: this is an example of the new IPADDRESS data type added in Athena engine v2 and IP Address contains function added in the Athena engine v3.  Be sure that you've [enabled Athena engine v3](https://aws.amazon.com/blogs/big-data/upgrade-to-athena-engine-version-3-to-increase-query-performance-and-access-more-analytics-features/)

```
SELECT *
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow_1_0"
WHERE src_endpoint.ip <> '-'
	AND dst_endpoint.ip <> '-'
	AND (
		(
			NOT (
				contains(
					'10.0.0.0/8',
					(CAST(src_endpoint.ip AS IPADDRESS))
				)
				OR contains(
					'172.16.0.0/12',
					(CAST(src_endpoint.ip AS IPADDRESS))
				)
				OR contains(
					'192.168.0.0/16',
					(CAST(src_endpoint.ip AS IPADDRESS))
				)
			)
			AND (
				contains(
					'10.0.0.0/8',
					(CAST(dst_endpoint.ip AS IPADDRESS))
				)
				OR contains(
					'172.16.0.0/12',
					(CAST(dst_endpoint.ip AS IPADDRESS))
				)
				OR contains(
					'192.168.0.0/16',
					(CAST(dst_endpoint.ip AS IPADDRESS))
				)
			)
		)
		OR (
			NOT (
				contains(
					'10.0.0.0/8',
					(CAST(dst_endpoint.ip AS IPADDRESS))
				)
				OR contains(
					'172.16.0.0/12',
					(CAST(dst_endpoint.ip AS IPADDRESS))
				)
				OR contains(
					'192.168.0.0/16',
					(CAST(dst_endpoint.ip AS IPADDRESS))
				)
			)
			AND (
				contains(
					'10.0.0.0/8',
					(CAST(src_endpoint.ip AS IPADDRESS))
				)
				OR contains(
					'172.16.0.0/12',
					(CAST(src_endpoint.ip AS IPADDRESS))
				)
				OR contains(
					'192.168.0.0/16',
					(CAST(src_endpoint.ip AS IPADDRESS))
				)
			)
		)
	)
	AND eventday >= '20230530'
	AND eventday <= '20230631'
    AND accountid = '111122223333'
	AND region in ('us-east-1','us-east-2','us-west-2','us-west-2')
```


**Query:** Search for all internal-to-internal VPC Flow records for the internal VPC Subnets in the private 172.16.0.0/12 address space
> NOTE: this is an example of the new IPADDRESS data type added in Athena engine v2 and IP Address contains function added in the Athena engine v3.  Be sure that you've [enabled Athena engine v3](https://aws.amazon.com/blogs/big-data/upgrade-to-athena-engine-version-3-to-increase-query-performance-and-access-more-analytics-features/)

```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow_1_0"
WHERE src_endpoint.ip <> '-'
AND dst_endpoint.ip <> '-'
AND contains('172.16.0.0/12', cast(src_endpoint.ip as IPADDRESS)) 
AND contains('172.16.0.0/12', cast(dst_endpoint.ip as IPADDRESS))
AND eventday >= '20230530'
AND eventday <= '20230631'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
```

**Query:**  Search for all VPC Flow records _except_ the internal-to-internal records for VPC Subnets in the private 172.16.0.0/12 address space.  Useful to filter out internal VPC traffic and only show traffic to or from external IP Addresses.

```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow_1_0"
WHERE src_endpoint.ip <> '-'
AND dst_endpoint.ip <> '-'
AND NOT (
    contains('172.16.0.0/12', cast(src_endpoint.ip as IPADDRESS)) 
    AND contains('172.16.0.0/12', cast(dst_endpoint.ip as IPADDRESS))
)
AND eventday >= '20230530'
AND eventday <= '20230631'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
```
