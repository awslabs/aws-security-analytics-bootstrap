/*
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: Apache-2.0
*/

-- PREVIEW TABLE
-- preview first 10 rows with all fields, quick way to verify everything is setup correctly

SELECT * from r53dns
LIMIT 10;

-- PARTITION TESTS 
/*   NOTE: if there are no constraints a partition (account, region, or date) then by default ALL data will be scanned
           this could lead to costly query, always consider using at least one partition constraint.

           Note that this is the case even if you have other constraints in a query (e.g. sourceaddress = '192.0.2.1'),
           only constraints using partition fields (date_partition, region_partition, account_partition)
           will limit the amount of data scanned.
*/        

-- preview first 10 rows with all fields, limited to a single account
SELECT * from r53dns
WHERE account_partition = '111122223333'
LIMIT 10;

-- preview first 10 rows with all fields, limited to multiple accounts
SELECT * from r53dns
WHERE account_partition in ('111122223333','444455556666','123456789012')
LIMIT 10;

-- preview first 10 rows with all fields, limited to a single vpc
SELECT * from r53dns
WHERE vpc_partition = 'vpc-00000001'
LIMIT 10;

-- preview first 10 rows with all fields, limited to multiple vpcs
SELECT * from r53dns
WHERE vpc_partition in ('vpc-00000001','vpc-00000002','vpc-00000003')
LIMIT 10;

-- NOTE: date_partition format is 'YYYY/MM/DD' as a string
-- preview first 10 rows with all fields, limited to a certain date range
SELECT * from r53dns
WHERE date_partition >= '2020/07/01'
AND date_partition <= '2020/07/31'
LIMIT 10;

-- preview first 10 rows with all fields, limited to the past 30 days (relative)
SELECT * from r53dns
WHERE date_partition >= date_format(date_add('day',-30,current_timestamp), '%Y/%m/%d')
LIMIT 10;

-- preview first 10 rows with all fields, limited by a combination partition constraints
-- NOTE: narrowing the scope of the query as much as possible will improve performance and minimize cost
SELECT * from r53dns
WHERE date_partition >= '2020/07/01'
AND date_partition <= '2020/07/31'
AND account_partition = '111122223333'
AND vpc_partition in ('vpc-00000001','vpc-00000002','vpc-00000003')
LIMIT 10;

-- ANALYSIS EXAMPLES

-- Sort queries by requestor instance count and query count
SELECT  query_name, query_type, array_distinct(filter(array_agg(srcids), q -> q.instance IS NOT NULL)) as instances, 
        cardinality(array_distinct(filter(array_agg(srcids), q -> q.instance IS NOT NULL))) as query_count 
FROM r53dns
WHERE date_partition >= '2020/07/01'
AND date_partition <= '2020/07/31'
AND account_partition = '111122223333'
AND vpc_partition in ('vpc-00000001','vpc-00000002','vpc-00000003')
GROUP BY query_name, query_type
ORDER by query_count DESC;

-- Summary with count of each time a name name queried
SELECT  query_name, query_type, count(*) as query_count FROM r53dns
WHERE date_partition >= '2020/07/01'
AND date_partition <= '2020/07/31'
AND account_partition = '111122223333'
AND vpc_partition in ('vpc-00000001','vpc-00000002','vpc-00000003')
GROUP BY query_name, query_type
ORDER BY query_count DESC;

-- Summary with count of each time a AAAA record name name queried
SELECT  query_name, query_type, count(*) as query_count FROM r53dns
WHERE query_type <> 'AAAA'
AND date_partition >= '2020/07/01'
AND date_partition <= '2020/07/31'
AND account_partition = '111122223333'
AND vpc_partition in ('vpc-00000001','vpc-00000002','vpc-00000003')
GROUP BY query_name, query_type
ORDER BY query_count DESC;

-- Summary with count of each time a AAAA record name name queried
-- split out TLD and SLD (note: doesn't properly handle TLDs containing a '.' (e.g. .com.br)
SELECT element_at(split(query_name,'.'),-2) AS tld, 
        element_at(split(query_name,'.'),-3) AS sld, 
        query_name, query_type, 
        count(*) AS query_count
FROM r53dns
WHERE query_type <> 'AAAA'
AND date_partition >= '2020/07/01'
AND date_partition <= '2020/07/31'
AND account_partition = '111122223333'
AND vpc_partition in ('vpc-00000001','vpc-00000002','vpc-00000003')
GROUP BY  query_name, query_type
ORDER BY  query_count DESC;

-- Get records that that resolve to a specific IP
SELECT * FROM r53dns
WHERE contains(transform(answers, x-> x.rdata), '203.0.113.2')
AND date_partition >= '2020/07/01'
AND date_partition <= '2020/07/31'
AND account_partition = '111122223333'
AND vpc_partition in ('vpc-00000001','vpc-00000002','vpc-00000003');
