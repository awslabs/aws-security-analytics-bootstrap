/*
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: Apache-2.0
*/

-- PREVIEW TABLE
-- preview first 10 rows with all fields, quick way to verify everything is setup correctly

SELECT * from alb_logs
LIMIT 10;

-- PARTITION TESTS 
/*   NOTE: if there are no constraints a partition (account, region, or date) then by default ALL data will be scanned
           this could lead to costly query, always consider using at least one partition constraint.

           Note that this is the case even if you have other constraints in a query (e.g. sourceaddress = '192.0.2.1'),
           only constraints using partition fields (date_partition, region_partition, account_partition)
           will limit the amount of data scanned.
*/        

-- preview first 10 rows with all fields, limited to a single account
SELECT * from alb_logs
WHERE account_partition = '111122223333'
LIMIT 10;

-- preview first 10 rows with all fields, limited to multiple accounts
SELECT * from alb_logs
WHERE account_partition in ('111122223333','444455556666','123456789012')
LIMIT 10;

-- -- preview first 10 rows with all fields, limited to a single region
-- SELECT * from alb_logs
-- WHERE region_partition = 'us-east-1'
-- LIMIT 10;

-- -- preview first 10 rows with all fields, limited to multiple regions
-- SELECT * from alb_logs
-- WHERE region_partition in ('us-east-1','us-east-2','us-west-2')
-- LIMIT 10;

-- NOTE: date_partition format is 'YYYY/MM/DD' as a string
-- preview first 10 rows with all fields, limited to a certain date range
SELECT * from alb_logs
WHERE date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
LIMIT 10;

-- preview first 10 rows with all fields, limited to the past 30 days (relative)
SELECT * from alb_logs
WHERE date_partition >= date_format(date_add('day',-30,current_timestamp), '%Y/%m/%d')
LIMIT 10;

-- preview first 10 rows with all fields, limited by a combination partition constraints
-- NOTE: narrowing the scope of the query as much as possible will improve performance and minimize cost
SELECT * from alb_logs
WHERE date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
AND account_partition = '111122223333'
LIMIT 10;

-- ANALYSIS EXAMPLES
-- NOTE: default partition constraints have been provided for each query, 
--       be sure to add the appropriate partition constraints to the WHERE clause as shown above
/*  
    DEFAULT partition constraints: 
        WHERE date_partition >= '2021/07/01'
        AND date_partition <= '2021/07/31'
        AND account_partition = '111122223333'

    Be sure to modify or remove these to fit the scope of your intended analysis
*/

-- Get list of ALBs in all accounts
SELECT account_partition, elb FROM alb_logs
GROUP BY account_partition, elb
ORDER BY account_partition ASC

-- Get list ALB ordered by the number of records 
SELECT elb, account_partition, count(*) as record_count FROM alb_logs
WHERE date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
GROUP BY elb, account_partition
ORDER BY record_count DESC

-- Get count of client IPs for specific alb 
SELECT client_ip, count(*) as record_count FROM alb_logs
WHERE date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
AND elb LIKE '%testalb%'
GROUP BY client_ip
ORDER BY record_count DESC

-- Get count of requests from specific client IPs
SELECT elb, account_partition, count(*) as record_count FROM alb_logs
WHERE date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
AND client_ip LIKE '69.110.128.117%'
GROUP BY elb, account_partition
ORDER BY record_count DESC

-- Get list of source IP/port and destination ALB in specifc AWS account ordered by the number of records 
SELECT type, elb, client_ip, count(*) as record_count FROM alb_logs
WHERE date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
AND account_partition = '111122223333'
GROUP BY type, elb, client_ip
ORDER BY record_count DESC

-- Get count of user agents ordered by the number of records lowest to highest 
SELECT user_agent, count(*) as record_count FROM alb_logs
WHERE date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
GROUP BY user_agent
ORDER BY record_count ASC

-- Get list of user agents for specific client IP
SELECT user_agent, count(*) as record_count FROM alb_logs
WHERE date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
AND client_ip LIKE '69.110.128.117%'
GROUP BY user_agent
ORDER BY record_count DESC

-- Get count requests with a specific elb status code
SELECT elb, account_partition, count(*) as record_count FROM alb_logs
WHERE date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
AND elb_status_code = '490'
GROUP BY elb, account_partition
ORDER BY record_count DESC

-- Get count requests with a specific target status code
SELECT elb, account_partition, count(*) as record_count FROM alb_logs
WHERE date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
AND target_status_code = '3900'
GROUP BY elb, account_partition
ORDER BY record_count DESC

-- Get count of all non https requests
SELECT elb, account_partition, count(*) as record_count FROM alb_logs
WHERE date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
AND type NOT LIKE 'https'
GROUP BY elb, account_partition
ORDER BY record_count DESC

-- Get count of all requests with specific ssl sipher
SELECT elb, account_partition, count(*) as record_count FROM alb_logs
WHERE date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
AND ssl_cipher LIKE '10.0%'
GROUP BY elb, account_partition
ORDER BY record_count DESC

-- Get requests info from specific client IPs to specific ALB
SELECT type, 
            time, 
            elb_status_code, 
            target_status_code, 
            received_bytes, 
            sent_bytes, 
            request_verb, 
            request_url, 
            request_proto, 
            user_agent, 
            ssl_cipher, 
            ssl_protocol, 
            trace_id, 
            domain_name,
            chosen_cert_arn, 
            matched_rule_priority,
            request_creation_time,
            redirect_url,
            actions_executed  
FROM alb_logs
WHERE date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
AND client_ip LIKE '69.110.128.117%'
AND elb LIKE '%testalb%'

