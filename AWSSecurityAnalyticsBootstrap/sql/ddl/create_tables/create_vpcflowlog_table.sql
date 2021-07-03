/* 
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: Apache-2.0

    Creates a VPC flow table for VPC flow logs delivered directly to an S3 bucket
    Includes partitioning configuration for multi-account, multi-region deployment as well as date in YYYY/MM/DD format
    Includes all available fields, including non-default v3 and v4 fields.
    NOTE: VPC flow fields must be configured in the order listed when configured, if they were configured in a different order you'll need to adjust the order their listed in the DDL below
*/

/*
    TODO: optionally update the table name "vpcflow" to the name you'd like to use for the VPC flow log table 
*/
CREATE EXTERNAL TABLE IF NOT EXISTS vpcflow (
  /*
    TODO: verify that VPC flow logs were configured to be generated in this order, if they weren't you'll need to rearrange the order below to match the order in which they were generated
    TIP: download a sample and check the first line of each log file for the field order,
       don't worry if they field names don't match exactly with the names in the top line of the log, Athena will import them based on their order
    NOTE: These v2 fields are in the default format and usually don't need to be adjusted, pay closer attention to the order of the v3/v4 fields below as there is no default ordering of those fields
  */
  version INT,
  account STRING,
  interfaceid STRING,
  sourceaddress STRING,
  destinationaddress STRING,
  sourceport INT,
  destinationport INT,
  protocol INT,
  numpackets INT,
  numbytes BIGINT,
  starttime INT,
  endtime INT,
  action STRING,
  logstatus STRING,
  /*
    NOTE: start of non-default v3 and v4 fields
          don't worry if you're source logs don't all include these fields, they'll just show as blank 
    TODO: If you're VPC flow logs include these fields, be sure to check the order their listed below is the same order they're configured in the flow log format
  */
  vpcid STRING,
  subnetid STRING,
  instanceid STRING,
  tcpflags SMALLINT,
  type STRING, 
  pktsrcaddr STRING,
  pktdstaddr STRING,
  region STRING,
  azid STRING,
  sublocationtype STRING,
  sublocationid STRING,
  pktsrcawsservice STRING,
  pktdstawsservice STRING,
  flowdirection STRING,
  trafficpath STRING
)
PARTITIONED BY
(
 date_partition STRING,
 region_partition STRING,
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
 "projection.region_partition.type" = "enum",
 "projection.region_partition.values" = "us-east-2,us-east-1,us-west-1,us-west-2,af-south-1,ap-east-1,ap-south-1,ap-northeast-3,ap-northeast-2,ap-southeast-1,ap-southeast-2,ap-northeast-1,ca-central-1,cn-north-1,cn-northwest-1,eu-central-1,eu-west-1,eu-west-2,eu-south-1,eu-west-3,eu-north-1,me-south-1,sa-east-1",
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
 "storage.location.template" = "s3://<bucket_name>/<optional_prefix>/AWSLogs/${account_partition}/vpcflowlogs/${region_partition}/${date_partition}"
);