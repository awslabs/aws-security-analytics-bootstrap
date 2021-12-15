/*
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: Apache-2.0
*/

-- PREVIEW TABLE
-- preview first 10 rows with all fields, quick way to verify everything is setup correctly

SELECT * from elb
LIMIT 10;

-- PARTITION TESTS 
/*   NOTE: if there are no constraints a partition (account, region, or date) then by default ALL data will be scanned
           this could lead to costly query, always consider using at least one partition constraint.

           Note that this is the case even if you have other constraints in a query (e.g. sourceaddress = '192.0.2.1'),
           only constraints using partition fields (date_partition, account_partition)
           will limit the amount of data scanned.
*/        

-- preview first 10 rows with all fields, limited to a single account
SELECT * from elb
WHERE account_partition = '111122223333'
LIMIT 10;

-- preview first 10 rows with all fields, limited to multiple accounts
SELECT * from elb
WHERE account_partition in ('111122223333','444455556666','123456789012')
LIMIT 10;

-- -- preview first 10 rows with all fields, limited to a single region
-- SELECT * from elb
-- WHERE region_partition = 'us-east-1'
-- LIMIT 10;

-- -- preview first 10 rows with all fields, limited to multiple regions
-- SELECT * from elb
-- WHERE region_partition in ('us-east-1','us-east-2','us-west-2')
-- LIMIT 10;

-- NOTE: date_partition format is 'YYYY/MM/DD' as a string
-- preview first 10 rows with all fields, limited to a certain date range
SELECT * from elb
WHERE date_partition >= '2021/07/01'
AND date_partition <= '2021/07/31'
LIMIT 10;

-- preview first 10 rows with all fields, limited to the past 30 days (relative)
SELECT * from elb
WHERE date_partition >= date_format(date_add('day',-30,current_timestamp), '%Y/%m/%d')
LIMIT 10;

-- preview first 10 rows with all fields, limited by a combination partition constraints
-- NOTE: narrowing the scope of the query as much as possible will improve performance and minimize cost
SELECT * from elb
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

elb-- Get list of ELBs in all accounts
SELECT account_partition, elb FROM elb
GROUP BY account_partition, elb
ORDER BY account_partition ASC

-- Get list ELB ordered by the number of records 
SELECT elb, account_partition, count(*) as record_count FROM elb
WHERE date_partition >= '2021/12/01'
AND date_partition <= '2021/12/31'
GROUP BY elb, account_partition
ORDER BY record_count DESC

-- Get list of listener IDs for all ELBs
SELECT listener_id, elb, account_partition FROM elb
WHERE date_partition >= '2021/12/01'
AND date_partition <= '2021/12/31'
GROUP BY listener_id, elb, account_partition
ORDER BY listener_id ASC

-- Get count of client IPs for specific elb 
SELECT client_ip, count(*) as record_count FROM elb
WHERE date_partition >= '2021/12/01'
AND date_partition <= '2021/12/31'
AND elb LIKE '%test-elb%'
GROUP BY client_ip
ORDER BY record_count DESC

-- Get count of requests from specific client IPs
SELECT elb, account_partition, count(*) as record_count FROM elb
WHERE date_partition >= '2021/12/01'
AND date_partition <= '2021/12/31'
AND client_ip LIKE '69.110.128.117%'
GROUP BY elb, account_partition
ORDER BY record_count DESC

-- Get list of source IP and destination ELB in specifc AWS account ordered by the number of records 
SELECT elb, client_ip, count(*) as record_count FROM elb
WHERE date_partition >= '2021/12/01'
AND date_partition <= '2021/12/31'
AND account_partition = '111122223333'
GROUP BY elb, client_ip
ORDER BY record_count DESC

-- Get tls protocol versions used on ELBs
SELECT tls_protocol_version, elb, account_partition FROM elb
WHERE date_partition >= '2021/12/01'
AND date_partition <= '2021/12/31'
GROUP BY tls_protocol_version, elb, account_partition
ORDER BY tls_protocol_version ASC
 
-- Get tls cipher suite used on ELBs
SELECT tls_cipher_suite, elb, account_partition FROM elb
WHERE date_partition >= '2021/12/01'
AND date_partition <= '2021/12/31'
GROUP BY tls_cipher_suite, elb, account_partition
ORDER BY tls_cipher_suite ASC

-- Get certificates ARNs used on elbs
SELECT cert_arn, elb, account_partition FROM elb
WHERE date_partition >= '2021/12/01'
AND date_partition <= '2021/12/31'
GROUP BY cert_arn, elb, account_partition
ORDER BY cert_arn ASC

-- Get list of domain names for ELBs
SELECT domain_name, elb, account_partition FROM elb
WHERE date_partition >= '2021/12/01'
AND date_partition <= '2021/12/31'
GROUP BY domain_name, elb, account_partition
ORDER BY domain_name DESC

-- Get count of all requests by domain name
SELECT domain_name, elb, account_partition, count(*) as record_count FROM elb
WHERE date_partition >= '2021/12/01'
AND date_partition <= '2021/12/31'
GROUP BY domain_name, elb, account_partition
ORDER BY record_count DESC

-- Get requests info from specific client IPs to specific ELB
SELECT  type,
        version,
        time,
        elb,
        listener_id,
        client_ip,
        client_port,
        target_ip,
        target_port,
        tcp_connection_time_ms,
        tls_handshake_time_ms,
        received_bytes,
        sent_bytes,
        incoming_tls_alert,
        cert_arn string,
        certificate_serial,
        tls_cipher_suite,
        tls_protocol_version,
        tls_named_group,
        domain_name,
        alpn_fe_protocol,
        alpn_be_protocol,
        alpn_client_preference_list
FROM elb
WHERE date_partition >= '2021/12/01'
AND date_partition <= '2021/12/31'
AND client_ip LIKE '69.110.128.117%'
AND elb LIKE '%test-elb%'

