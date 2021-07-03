/*
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: Apache-2.0
*/

-- PREVIEW TABLE
-- preview first 10 rows with all fields, quick way to verify everything is setup correctly

SELECT * from vpcflow
LIMIT 10;

-- PARTITION TESTS 
/*   NOTE: if there are no constraints a partition (account, region, or date) then by default ALL data will be scanned
           this could lead to costly query, always consider using at least one partition constraint.

           Note that this is the case even if you have other constraints in a query (e.g. sourceaddress = '192.0.2.1'),
           only constraints using partition fields (date_partition, region_partition, account_partition)
           will limit the amount of data scanned.
*/        

-- preview first 10 rows with all fields, limited to a single account
SELECT * from vpcflow
WHERE account_partition = '111122223333'
LIMIT 10;

-- preview first 10 rows with all fields, limited to multiple accounts
SELECT * from vpcflow
WHERE account_partition in ('111122223333','444455556666','123456789012')
LIMIT 10;

-- preview first 10 rows with all fields, limited to a single region
SELECT * from vpcflow
WHERE region_partition = 'us-east-1'
LIMIT 10;

-- preview first 10 rows with all fields, limited to multiple regions
SELECT * from vpcflow
WHERE region_partition in ('us-east-1','us-east-2','us-west-2')
LIMIT 10;

-- NOTE: date_partition format is 'YYYY/MM/DD' as a string
-- preview first 10 rows with all fields, limited to a certain date range
SELECT * from vpcflow
WHERE date_partition >= '2020/07/01'
AND date_partition <= '2020/07/31'
LIMIT 10;

-- preview first 10 rows with all fields, limited to the past 30 days (relative)
SELECT * from vpcflow
WHERE date_partition >= date_format(date_add('day',-30,current_timestamp), '%Y/%m/%d')
LIMIT 10;

-- preview first 10 rows with all fields, limited by a combination partition constraints
-- NOTE: narrowing the scope of the query as much as possible will improve performance and minimize cost
SELECT * from vpcflow
WHERE date_partition >= '2020/07/01'
AND date_partition <= '2020/07/31'
AND account_partition = '111122223333'
AND region_partition in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
LIMIT 10;

-- ANALYSIS EXAMPLES
-- NOTE: default partition constraints have been provided for each query, 
--       be sure to add the appropriate partition constraints to the WHERE clause as shown above
/*  
    DEFAULT partition constraints: 
        WHERE date_partition >= '2020/07/01'
        AND date_partition <= '2020/07/31'
        AND account_partition = '111122223333'
        AND region_partition in ('us-east-1','us-east-2','us-west-2', 'us-west-2')

    Be sure to modify or remove these to fit the scope of your intended analysis
*/

-- Get list source/destination IP pairs ordered by the number of records 
SELECT region, instanceid, sourceaddress, destinationaddress, count(*) as record_count FROM vpcflow
WHERE date_partition >= '2020/07/01'
AND date_partition <= '2020/07/31'
AND account_partition = '111122223333'
AND region_partition in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY region, instanceid, sourceaddress, destinationaddress
ORDER BY record_count DESC

-- Get a summary of records between a given source/destination IP pair, ordered by the total number of bytes
SELECT region, instanceid, sourceaddress, destinationaddress, sum(numbytes) as byte_count FROM vpcflow
WHERE (sourceaddress = '192.0.2.1' OR destinationaddress = '192.0.2.1')
AND (sourceaddress = '203.0.113.2' OR destinationaddress = '203.0.113.2')
AND date_partition >= '2020/07/01'
AND date_partition <= '2020/07/31'
AND account_partition = '111122223333'
AND region_partition in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY region, instanceid, sourceaddress, destinationaddress
ORDER BY byte_count DESC

-- Get a summary of the number of bytes sent from port 443 limited to a single instance
-- NOTE: for remote IPs this represents the amount data downloaded from port 443 by the instance,
--       for instance IPs this represents the amount data downloaded by remost hosts from the instance on port 443
SELECT region, instanceid, sourceaddress, sourceport, destinationaddress, sum(numbytes) as byte_count FROM vpcflow
WHERE instanceid = 'i-000000000000000'
AND sourceport = 443
AND date_partition >= '2020/07/01'
AND date_partition <= '2020/07/31'
AND account_partition = '111122223333'
AND region_partition in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY region, instanceid, sourceaddress, sourceport, destinationaddress
ORDER BY byte_count DESC

-- Get a summary of the number of bytes sent to port 443 limited to a single instance
-- NOTE: for remote IPs this represents the amount data uploaded to port 443 by the instance,
--       for instance IPs this represents the amount data uploaded by remost hosts to the instance on port 443
SELECT region, instanceid, sourceaddress, destinationaddress, destinationport, sum(numbytes) as byte_count FROM vpcflow
WHERE instanceid = 'i-000000000000000'
AND destinationport = 443
AND date_partition >= '2020/07/01'
AND date_partition <= '2020/07/31'
AND account_partition = '111122223333'
AND region_partition in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY region, instanceid, sourceaddress, destinationaddress, destinationport
ORDER BY byte_count DESC

-- Get a summary with the number of bytes for each src_ip,src_port,dst_ip,dst_port quad across all records to or from a specific IP
SELECT sourceaddress, destinationaddress, sourceport, destinationport, sum(numbytes) as byte_count FROM vpcflow
WHERE (sourceaddress = '192.0.2.1' OR destinationaddress = '192.0.2.1')
AND date_partition >= '2020/07/01'
AND date_partition <= '2020/07/31'
AND account_partition = '111122223333'
AND region_partition in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY sourceaddress, destinationaddress, sourceport, destinationport
ORDER BY byte_count DESC

-- Get all flow records between two IPs showing flow_direction (requires v5 flow-direction field to be enabled)
SELECT from_unixtime(starttime) AS start_time,
from_unixtime(endtime) AS end_time,
interfaceid,
sourceaddress,
destinationaddress,
sourceport,
destinationport,
numpackets,
numbytes,
flow_direction,
action
FROM vpcflow
WHERE (sourceaddress = '192.0.2.1'
AND destinationaddress = '192.0.2.254')
OR (sourceaddress = '192.0.2.254'
AND destinationaddress = '192.0.2.1')
ORDER BY starttime ASC

-- List when source ips were first seen / last seen with a summary of destination ip/instances/ports
SELECT sourceaddress,
         min(starttime) AS first_seen,
         max(endtime) AS last_seen,
         array_agg(DISTINCT(destinationaddress)),
         array_agg(DISTINCT(instanceid)),
         array_agg(DISTINCT(destinationport))
FROM vpcflow
WHERE destinationport < 32768 -- skip ephemeral ports, since we're looking for inbound connections to service ports
AND date_partition >= '2020/07/01'
AND date_partition <= '2020/07/31'
AND account_partition = '111122223333'
AND region_partition in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY sourceaddress
ORDER by first_seen ASC


-- Daily Transfer Report on Top 10 Internal IPs with large transfers, limited to source addresses in network 192.0.2.0/24
SELECT vpcflow.event_date, vpcflow.sourceaddress, vpcflow.destinationaddress, sum(vpcflow.numbytes) as byte_count
FROM vpcflow 
INNER JOIN (SELECT sourceaddress, sum(numbytes) as byte_count FROM vpcflow
WHERE sourceaddress like '192.0.2.%'
AND date_partition >= '2020/07/01'
AND date_partition <= '2020/07/31'
AND account_partition = '111122223333'
AND region_partition in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY region, instanceid, sourceaddress, destinationaddress, destinationport
ORDER BY byte_count DESC
LIMIT 10) as top_n 
ON top_n.sourceaddress = vpcflow.sourceaddress
WHERE date_partition >= '2020/07/01'
AND date_partition <= '2020/07/31'
AND account_partition = '111122223333'
AND region_partition in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
GROUP BY vpcflow.event_date, vpcflow.sourceaddress, vpcflow.destinationaddress
ORDER BY vpcflow.event_date ASC, vpcflow.sourceaddress ASC, vpcflow.destinationaddress ASC, byte_count DESC

-- Search for traffic between a private (RFC1918) IP address and a public (non-RFC1918) IP address
-- NOTE: this is an example of using the new IPADDRESS data type, as string a string comparison would correctly compare IP addresses
SELECT *
FROM vpcflow
WHERE (sourceaddress <> '-' AND destinationaddress <> '-')
AND (    (
         NOT ( (CAST(sourceaddress AS IPADDRESS) > IPADDRESS '10.0.0.0'
         AND CAST(sourceaddress AS IPADDRESS) < IPADDRESS '10.255.255.255')
         OR (CAST(sourceaddress AS IPADDRESS) > IPADDRESS '172.16.0.0'
         AND CAST(sourceaddress AS IPADDRESS) < IPADDRESS '172.31.255.255')
         OR (CAST(sourceaddress AS IPADDRESS) > IPADDRESS '192.168.0.0'
         AND CAST(sourceaddress AS IPADDRESS) < IPADDRESS '192.168.255.255'))
     
         AND ( (CAST(destinationaddress AS IPADDRESS) > IPADDRESS '10.0.0.0'
         AND CAST(destinationaddress AS IPADDRESS) < IPADDRESS '10.255.255.255')
         OR (CAST(destinationaddress AS IPADDRESS) > IPADDRESS '172.16.0.0'
         AND CAST(destinationaddress AS IPADDRESS) < IPADDRESS '172.31.255.255')
         OR (CAST(destinationaddress AS IPADDRESS) > IPADDRESS '192.168.0.0'
         AND CAST(destinationaddress AS IPADDRESS) < IPADDRESS '192.168.255.255'))
         )
         
      OR (
         NOT ( (CAST(destinationaddress AS IPADDRESS) > IPADDRESS '10.0.0.0'
         AND CAST(destinationaddress AS IPADDRESS) < IPADDRESS '10.255.255.255')
         OR (CAST(destinationaddress AS IPADDRESS) > IPADDRESS '172.16.0.0'
         AND CAST(destinationaddress AS IPADDRESS) < IPADDRESS '172.31.255.255')
         OR (CAST(destinationaddress AS IPADDRESS) > IPADDRESS '192.168.0.0'
         AND CAST(destinationaddress AS IPADDRESS) < IPADDRESS '192.168.255.255'))
     
         AND ( (CAST(sourceaddress AS IPADDRESS) > IPADDRESS '10.0.0.0'
         AND CAST(sourceaddress AS IPADDRESS) < IPADDRESS '10.255.255.255')
         OR (CAST(sourceaddress AS IPADDRESS) > IPADDRESS '172.16.0.0'
         AND CAST(sourceaddress AS IPADDRESS) < IPADDRESS '172.31.255.255')
         OR (CAST(sourceaddress AS IPADDRESS) > IPADDRESS '192.168.0.0'
         AND CAST(sourceaddress AS IPADDRESS) < IPADDRESS '192.168.255.255'))
         )
     )
AND date_partition >= '2020/07/01'
AND date_partition <= '2020/07/31'
AND account_partition = '111122223333'
AND region_partition in ('us-east-1','us-east-2','us-west-2', 'us-west-2')