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

**Query:** Search for activity by a specific IAM User
> NOTE: this query is similar to the one above, but will search for just a certain access key that's associated with an IAM User
```
SELECT time, eventhour, identity.user.uuid, identity.user.name, identity.user.credential_uid, api.operation, unmapped['requestParameters.userName'] as requestParametersUsername, unmapped['requestParameters.policyArn'] as requestParametersPolicyArn, api.response
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail"
WHERE identity.user.type = 'IAMUser'
AND identity.user.name = '{username}'
AND eventhour >= '2022110100'
AND eventhour <= '2022110700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2');
```

**Query:** Search for activity associated with a specific IAM User's Access Key
> NOTE: this query is similar to the one above, but will search for just a certain access key that's associated with an IAM User
```
SELECT time, eventhour, identity.user.uuid, identity.user.name, identity.user.credential_uid, api.operation, unmapped['requestParameters.userName'] as requestParametersUsername, unmapped['requestParameters.policyArn'] as requestParametersPolicyArn, api.response
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_cloud_trail"
WHERE identity.user.type = 'IAMUser'
AND identity.user.credential_uid = '{accesskeyid}'
AND eventhour >= '2022110100'
AND eventhour <= '2022110700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2');
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

## VPC Flow

### PREVIEW TABLE

**Query:** Preview first 10 rows with all fields, quick way to verify everything is setup correctly

```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow"
LIMIT 10;
```

### VPCFLOW PARTITION TESTS 
> **NOTE:** if there are no partition constraints (accountid, region, or eventhour) then by default ALL data will be scanned this could lead to costly query, always consider using at least one partition constraint.
> 
> Note that this is the case even if you have other constraints in a query (e.g. sourceipaddress = '192.0.2.1'), only constraints using partition fields (eventhour, region, accountid) will limit the amount of data scanned.

**Query:** Preview first 10 rows with all fields, limited to a single account

```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow"
WHERE accountid = '111122223333'
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited to multiple accounts
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow"
WHERE accountid in ('111122223333','444455556666','123456789012')
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited to a single region
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow"
WHERE region = 'us-east-1'
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited to multiple regions
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow"
WHERE region in ('us-east-1','us-east-2','us-west-2')
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited to a certain date range
> NOTE: eventhour format is 'YYYYMMDDHH' as a string

SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow"
WHERE eventhour >= '2022110100'
AND eventhour <= '2022111700'
LIMIT 10;

**Query:** Preview first 10 rows with all fields, limited to the past 30 days (relative)
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow"
WHERE eventhour >= date_format(date_add('day',-30,current_timestamp), '%Y%m%d%H')
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited by a combination partition constraints

> NOTE: narrowing the scope of the query as much as possible will improve performance and minimize cost
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow"
WHERE eventhour >= '2022110100'
AND eventhour <= '2022111700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
LIMIT 10;
```
### VPC FLOW ANALYSIS EXAMPLES

> NOTE: default partition constraints have been provided for each query, be sure to add the appropriate partition constraints to the WHERE clause as shown in the section above

> DEFAULT partition constraints: 
```
    WHERE eventhour >= '2022110100'
    AND eventhour <= '2022110700'
    AND accountid = '111122223333'
    AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
```

**Query:** Get list source/destination IP pairs ordered by the number of records 
```
SELECT region, src_endpoint.ip as src_ip, dst_endpoint.ip as dst_ip, count(*) as record_count FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow"
WHERE eventhour >= '2022110100'
AND eventhour <= '2022111700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY region, src_endpoint.ip, dst_endpoint.ip
ORDER BY record_count DESC
```

**Query:** Get a summary of records between a given source/destination IP pair, ordered by the total number of bytes

```
SELECT region, src_endpoint.ip as src_ip, dst_endpoint.ip as dst_ip, sum(traffic.bytes) as byte_count FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow"
WHERE (src_endpoint.ip = '192.0.2.1' OR dst_endpoint.ip = '192.0.2.1')
AND (src_endpoint.ip = '203.0.113.2' OR dst_endpoint.ip = '203.0.113.2')
AND eventhour >= '2022110100'
AND eventhour <= '2022111700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY region, dst_endpoint.instance_uid, src_endpoint.ip, dst_endpoint.ip
ORDER BY byte_count DESC
```

**Query:** Get a summary of the number of bytes sent from port 443 limited to a single instance
> NOTE: for remote IPs this represents the amount data downloaded from port 443 by the instance, for instance IPs this represents the amount data downloaded by remost hosts from the instance on port 443

```
SELECT region, dst_endpoint.instance_uid as dst_instance_id, src_endpoint.ip as src_ip, src_endpoint.port as src_port, dst_endpoint.ip as dst_ip, sum(traffic.bytes) as byte_count FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow"
WHERE dst_endpoint.instance_uid = 'i-000000000000000'
AND src_endpoint.port = 443
AND eventhour >= '2022110100'
AND eventhour <= '2022111700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY region, dst_endpoint.instance_uid, src_endpoint.ip, src_endpoint.port, dst_endpoint.ip
ORDER BY byte_count DESC
```

**Query:** Get a summary with the number of bytes for each src_ip,src_port,dst_ip,dst_port quad across all records to or from a specific IP

```
SELECT src_endpoint.ip as src_ip, dst_endpoint.ip as dst_ip, src_endpoint.port as src_port, dst_endpoint.port as dst_port, sum(traffic.bytes) as byte_count FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow"
WHERE (src_endpoint.ip = '192.0.2.1' OR dst_endpoint.ip = '192.0.2.1')
AND eventhour >= '2022110100'
AND eventhour <= '2022111700'
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
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow"
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
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow"
WHERE dst_endpoint.port < 32768 -- skip ephemeral ports, since we're looking for inbound connections to service ports
AND eventhour >= '2022110100'
AND eventhour <= '2022111700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY src_endpoint.ip
ORDER by first_seen ASC
```


**Query:** Transfer Report on Top 10 Internal IPs with large transfers, limited to source addresses in network 192.0.2.0/24

```
SELECT vpcflow.eventhour, vpcflow.src_endpoint.ip as src_endpoint_ip, vpcflow.dst_endpoint.ip as dst_endpoint_ip, sum(vpcflow.traffic.bytes) as byte_count
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow" as vpcflow
INNER JOIN (SELECT src_endpoint.ip as src_endpoint_ip, sum(traffic.bytes) as byte_count FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow" 
WHERE src_endpoint.ip <> '-'
AND contains('192.0.2.0/24', cast(src_endpoint.ip as IPADDRESS))
AND eventhour >= '2022110100'
AND eventhour <= '2022111700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY region, dst_endpoint.instance_uid, src_endpoint.ip, dst_endpoint.ip, dst_endpoint.port
ORDER BY byte_count DESC
LIMIT 10 ) as top_n 
ON top_n.src_endpoint_ip = vpcflow.src_endpoint.ip
WHERE eventhour >= '2022110100'
AND eventhour <= '2022111700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY vpcflow.eventhour, vpcflow.src_endpoint.ip, vpcflow.dst_endpoint.ip
ORDER BY vpcflow.eventhour ASC, vpcflow.src_endpoint.ip ASC, vpcflow.dst_endpoint.ip ASC, byte_count DESC
```

**Query:** Search for traffic between a private (RFC1918) IP address and a public (non-RFC1918) IP address
> NOTE: this is an example of the new IPADDRESS data type added in Athena engine v2 and IP Address contains function added in the Athena engine v3.  Be sure that you've [enabled Athena engine v3](https://aws.amazon.com/blogs/big-data/upgrade-to-athena-engine-version-3-to-increase-query-performance-and-access-more-analytics-features/)

```
SELECT *
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow"
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
	AND eventhour >= '2022110100'
	AND eventhour <= '2022111700'
    AND accountid = '111122223333'
	AND region in ('us-east-1','us-east-2','us-west-2','us-west-2')
```


**Query:** Search for all internal-to-internal VPC Flow records for the internal VPC Subnets in the private 172.16.0.0/12 address space
> NOTE: this is an example of the new IPADDRESS data type added in Athena engine v2 and IP Address contains function added in the Athena engine v3.  Be sure that you've [enabled Athena engine v3](https://aws.amazon.com/blogs/big-data/upgrade-to-athena-engine-version-3-to-increase-query-performance-and-access-more-analytics-features/)

```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow"
WHERE src_endpoint.ip <> '-'
AND dst_endpoint.ip <> '-'
AND contains('172.16.0.0/12', cast(src_endpoint.ip as IPADDRESS)) 
AND contains('172.16.0.0/12', cast(dst_endpoint.ip as IPADDRESS))
AND eventhour >= '2022110100'
AND eventhour <= '2022111700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
```

**Query:**  Search for all VPC Flow records _except_ the internal-to-internal records for VPC Subnets in the private 172.16.0.0/12 address space.  Useful to filter out internal VPC traffic and only show traffic to or from external IP Addresses.

```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_vpc_flow"
WHERE src_endpoint.ip <> '-'
AND dst_endpoint.ip <> '-'
AND NOT (
    contains('172.16.0.0/12', cast(src_endpoint.ip as IPADDRESS)) 
    AND contains('172.16.0.0/12', cast(dst_endpoint.ip as IPADDRESS))
)
AND eventhour >= '2022110100'
AND eventhour <= '2022111700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
```

## Route53

### PREVIEW TABLE

**Query:** Preview first 10 rows with all fields, quick way to verify everything is setup correctly
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_route53"
LIMIT 10;
```

### ROUTE 53 PARTITION TESTS 
> **NOTE:** if there are no partition constraints (accountid, region, or eventhour) then by default ALL data will be scanned this could lead to costly query, always consider using at least one partition constraint.
> 
> Note that this is the case even if you have other constraints in a query (e.g. sourceipaddress = '192.0.2.1'), only constraints using partition fields (eventhour, region, accountid) will limit the amount of data scanned.


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
> NOTE: eventhour format is 'YYYYMMDDHH' as a string
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_route53"
WHERE eventhour >= '2022110100'
AND eventhour <= '2022110700'
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited to the past 30 days (relative)
```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_route53"
WHERE eventhour >= date_format(date_add('day',-30,current_timestamp), '%Y%m%d%H')
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited by a combination of partition constraints
> NOTE: narrowing the scope of the query as much as possible will improve performance and minimize cost

```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_route53"
WHERE eventhour >= '2022110100'
AND eventhour <= '2022110700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
LIMIT 10;
```

### ROUTE53 ANALYSIS EXAMPLES

**Query:** Sort queries by the number of isntances that requested each hostname

```
SELECT  query.hostname, query.type, cardinality(array_distinct(filter(array_agg(src_endpoint), q -> q.instance_uid IS NOT NULL))) as instance_count, array_distinct(filter(array_agg(src_endpoint), q -> q.instance_uid IS NOT NULL)) as instances
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_route53"
WHERE eventhour >= '2022110100'
AND eventhour <= '2022111700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY query.hostname, query.type
ORDER by instance_count DESC;
```

**Query:** Sort queries by the number of queries for each each hostname

```
SELECT  query.hostname, query.type, count(*) as query_count FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_route53"
WHERE eventhour >= '2022110100'
AND eventhour <= '2022111700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY query.hostname, query.type
ORDER BY query_count DESC;
```

**Query:** Summary with count of each time an A record type of a hostname was queried
```
SELECT  query.hostname, query.type, count(*) as query_count FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_route53"
WHERE query.type = 'A'
AND eventhour >= '2022110100'
AND eventhour <= '2022111700'
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
AND eventhour >= '2022110100'
AND eventhour <= '2022111700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY  query.hostname, query.type
ORDER BY  query_count DESC;
```

**Query:** Get records that that resolve to a specific IP (e.g., 203.0.113.2)

```
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_route53"
WHERE contains(transform(answers, x-> x.rdata), '203.0.113.2')
AND eventhour >= '2022110100'
AND eventhour <= '2022111700'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2');
```
