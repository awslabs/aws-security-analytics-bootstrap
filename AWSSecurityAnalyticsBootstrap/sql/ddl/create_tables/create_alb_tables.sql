/* 
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: Apache-2.0
    Creates a alb_logs table for alb logs delivered directly to an S3 bucket
    Includes partitioning configuration for multi-account deployment as well as date in YYYY/MM/DD format
*/

/*
    TODO: optionally update the table name "alb_logs" to the name you'd like to use for the ALB log table 
*/
CREATE EXTERNAL TABLE IF NOT EXISTS alb_logs (
    type string,
    time string,
    elb string,
    client_ip string,
    client_port int,
    target_ip string,
    target_port int,
    request_processing_time double,
    target_processing_time double,
    response_processing_time double,
    elb_status_code string,
    target_status_code string,
    received_bytes bigint,
    sent_bytes bigint,
    request_verb string,
    request_url string,
    request_proto string,
    user_agent string,
    ssl_cipher string,
    ssl_protocol string,
    target_group_arn string,
    trace_id string,
    domain_name string,
    chosen_cert_arn string,
    matched_rule_priority string,
    request_creation_time string,
    actions_executed string,
    redirect_url string,
    lambda_error_reason string,
    target_port_list string,
    target_status_code_list string,
    classification string,
    classification_reason string
)
PARTITIONED BY
(
 date_partition STRING,
 account_partition STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ' '
/*
    TODO: replace bucket_name and optional_prefix in LOCATION value, 
    if there's no prefix then remove the extra /
    example: s3://my_central_log_bucket/AWSLogs/ or s3://my_central_log_bucket/PROD/AWSLogs/
*/
LOCATION 's3://<bucket_name>/<optional_prefix>/AWSLogs/' 
TBLPROPERTIES
(
 "skip.header.line.count"="1", 
 "projection.enabled" = "true",
 "projection.date_partition.type" = "date",
 /* TODO: replace <YYYY>/<MM>/<DD> with the first date of your logs, example: 2020/11/30 */
 "projection.date_partition.range" = "<YYYY>/<MM>/<DD>,NOW", 
 "projection.date_partition.format" = "yyyy/MM/dd",
 "projection.date_partition.interval" = "1",
 "projection.date_partition.interval.unit" = "DAYS",
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
 "storage.location.template" = "s3://<bucket_name>/<optional_prefix>/AWSLogs/${account_partition}/elasticloadbalancing/<region>/${date_partition}"
);