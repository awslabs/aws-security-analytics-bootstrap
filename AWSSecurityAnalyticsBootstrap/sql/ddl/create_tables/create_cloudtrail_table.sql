/*
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: Apache-2.0

    TODO: optionally update the table name "cloudtrail" to the name you'd like to use for the CloudTrail table 
*/
CREATE EXTERNAL TABLE cloudtrail (
    eventversion STRING,
    useridentity STRUCT<
                type:STRING,
                principalid:STRING,
                arn:STRING,
                accountid:STRING,
                invokedby:STRING,
                accesskeyid:STRING,
                userName:STRING,
    sessioncontext:STRUCT<
    attributes:STRUCT<
                mfaauthenticated:STRING,
                creationdate:STRING>,
    sessionissuer:STRUCT<  
                type:STRING,
                principalId:STRING,
                arn:STRING, 
                accountId:STRING,
                userName:STRING>>>,
    eventtime STRING,
    eventsource STRING,
    eventname STRING,
    awsregion STRING,
    sourceipaddress STRING,
    useragent STRING,
    errorcode STRING,
    errormessage STRING,
    requestparameters STRING,
    responseelements STRING,
    additionaleventdata STRING,
    requestid STRING,
    eventid STRING,
    resources ARRAY<STRUCT<
                ARN:STRING,
                accountId:STRING,
                type:STRING>>,
    eventtype STRING,
    apiversion STRING,
    readonly STRING,
    recipientaccountid STRING,
    serviceeventdetails STRING,
    sharedeventid STRING,
    vpcendpointid STRING
)
PARTITIONED BY
(
    date_partition STRING,
    region_partition STRING,
    account_partition STRING
)
ROW FORMAT SERDE 'com.amazon.emr.hive.serde.CloudTrailSerde'
STORED AS INPUTFORMAT 'com.amazon.emr.cloudtrail.CloudTrailInputFormat'
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
    "storage.location.template" = "s3://<bucket_name>/<optional_prefix>/AWSLogs/${account_partition}/CloudTrail/${region_partition}/${date_partition}"
);