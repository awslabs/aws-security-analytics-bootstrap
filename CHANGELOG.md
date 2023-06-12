# Changelog - AWS Security Analytics Bootstrap

## [1.1.3] - 2023-06-12
- Added two new example IAM queries for Amazon Security Lake OCSF formatted Cloudtrail
- Updated all Amazon Security Lake example queries to the GA schema and OSCF formats (resolves issue #13)
- Split Amazon Security Lake example queries for Cloudtrail by event type (e.g. management, lambda, s3)
- Added Amazon Security Lake example queries for Cloudtrail Lambda data events
- Minor: moved preview-formatted example queries to a new branch AmazonSecurityLake_Preview for reference
- Minor: updated start and end time to be the same for all Amazon Security Lake OCSF examples queries (resolves issue #11)
- Minor: added Security Hub Amazon Security Lake queries to all query list

## [1.1.2] - 2022-02-02
- Added Amazon Security Lake OSCF formatted queries for Security Hub (contributed by Charles Roberts)

## [1.1.1] - 2022-01-10
- Coverted demo queries into Amazon Security Lake OSCF formatted queries

## [1.1.0] - 2022-10-17
- Updated to use Amazon Athena engine to v3 (latest) [link](https://docs.aws.amazon.com/athena/latest/ug/engine-versions-reference-0003.html)
- Added new demo VPC Flow log queries for Athena engine v3

## [1.0.0] - 2021-07-02
Initial Release under Apache License Version 2.0
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.

### New Features
#### CloudFormation Templates
  - CloudFormation template to deploy a ready to use AWS Security Analytics Environment
    - Ready to deploy, parameterized with walkthrough comments
    - Athena Workgroup
      - Encrypted output to specified location
      - Demo named queries
    - Glue Database
    - Glue Tables
      - AWS Cloudtrail
        - partitioned by account, region, and date with dynamic partition projection configuration 
      - Amazon Virtual Private Cloud (VPC) Flow Logs 
        - partitioned by account, region, and date with dynamic partition projection configuration
      - Amazon Route53 DNS Resolve Logs 
        - partitioned by account, VPC-id, and date with dynamic partition projection configuration
  - CloudFormation template to deploy IAM admin and user roles
    - Provides IAM policy examples to start using Athena following principle of least privilege
  - CloudFormation template to enable VPC Flow Logs with all availble fields (v2-v5) for a specified VPC, Subnet, or ENI
#### CREATE TABLE SQL statements
  - Enables adhoc creation of Glue Tables via Athena SQL statement:
    - AWS Cloudtrail
      - partitioned by account, region, and date with dynamic partition projection configuration 
    - Amazon Virtual Private Cloud (VPC) Flow Logs 
      - partitioned by account, region, and date with dynamic partition projection configuration
    - Amazon Route53 DNS Resolve Logs 
      - partitioned by account, VPC-id, and date with dynamic partition projection configuration
#### Demo Athena Queries
  - AWS Cloudtrail
  - Amazon Virtual Private Cloud (VPC) Flow Logs 
  - Amazon Route53 DNS Resolve Logs 

### Added
- Deployment Guide
- README
- Misc required project files

