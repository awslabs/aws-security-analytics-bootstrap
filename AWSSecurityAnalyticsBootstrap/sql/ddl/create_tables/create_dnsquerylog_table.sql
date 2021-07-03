/*
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: Apache-2.0

    TODO: optionally update the table name "dns" to the name you'd like to use for the DNS resolver log table 
*/

CREATE EXTERNAL TABLE IF NOT EXISTS r53dns (
    version FLOAT,
    account_id STRING,
    region STRING,
    vpc_id STRING,
    query_timestamp STRING,
    query_name STRING,
    query_type STRING,
    query_class STRING,
    rcode STRING,
    answers ARRAY<STRING>,
    srcaddr STRING,
    srcport INT,
    transport STRING,
    srcids STRING
)
PARTITIONED BY
(
    account_partition STRING,
    vpc_partition STRING,
    date_partition STRING
)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
STORED AS INPUTFORMAT 'org.apache.hadoop.mapred.TextInputFormat'
OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
/*
    TODO: replace bucket_name and optional_prefix in LOCATION value, 
    if there's no prefix then remove the extra /
    example: s3://my_central_log_bucket/AWSLogs/ or s3://my_central_log_bucket/PROD/AWSLogs/
*/
LOCATION 's3://<bucket_name>/<optional_prefix>/AWSLogs/' 
TBLPROPERTIES
(
    "projection.enabled" = "true",
    "projection.date_partition.type" = "date",
    /* TODO: replace <YYYY>/<MM>/<DD> with the first date of your logs, example: 2020/11/30 */
    "projection.date_partition.range" = "<YYYY>/<MM>/<DD>,NOW", 
    "projection.date_partition.format" = "yyyy/MM/dd",
    "projection.date_partition.interval" = "1",
    "projection.date_partition.interval.unit" = "DAYS",
    "projection.vpc_partition.type" = "enum",
    /*
        TODO: replace values in projection.vpc_partition.values with the list of VPC IDs that you want to include in this table
        example: "vpc-00000001,vpc-00000002,vpc-00000003"
        note: do not use any spaces, separate the values with a comma only (including spaces will cause a syntax error)
        if there is only one VPC ID, include it by itself with no comma, for example: "vpc-00000001"
    */
    "projection.vpc_partition.values" = "<vpc_id_1>,<vpc_id_2>,...",
    "projection.account_partition.type" = "enum",
    /*
        TODO: replace values in projection.account_partition.values with the list of AWS account numbers that you want to include in this table
        example: "0123456789,0123456788,0123456777"
        note: do not use any spaces, separate the values with a comma only (including spaces will cause a syntax error)
        if there is only one account, include it by itself with no comma, for example: "0123456789"
    */
    "projection.account_partition.values" = "<account_num_1>,<account_num_2>,...",
    /*
        TODO: Same as LOCATION, replace bucket_name and optional_prefix in storage.location.template value, 
        if there's no prefix then remove the extra /
        example: s3://my_central_log_bucket/AWSLogs/... or s3://my_central_log_bucket/PROD/AWSLogs/...
        NOTE: do not change parameters that look like ${...}, those are template variables, only replace values in angle brackets <...>
    */
    "storage.location.template" = "s3://<bucket_name>/<optional_prefix>/AWSLogs/${account_partition}/vpcdnsquerylogs/${vpc_partition}/${date_partition}"
);