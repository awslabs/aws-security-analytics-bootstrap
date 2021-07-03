# AWS Security Analytics Bootstrap Deployment Guide

## 1 Prerequisites
### 1.1 Verify AWS Service Logs are Enabled and Correctly Configured
The first step is to verify that the expected logs have been enabled and are currently being archived directly to an Amazon S3 bucket.  AWS Security Analytics Bootstrap currently requires AWS service logs to be configured to be sent directly to S3 and unmodified.  For additional assistance enabling AWS service logs, consider using [Assisted Log Enabler for AWS](https://github.com/awslabs/assisted-log-enabler-for-aws).  Although AWS service log configuration and enablement is out of scope for this project, the following are a few suggestions:
- Centralize all of your AWS service logs into a single S3 bucket or an S3 bucket per log type
- Enable [AWS CloudTrail](https://docs.aws.amazon.com/cloudtrail/index.html) for all accounts
- Enable [Amazon Virtual Private Cloud (VPC) Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html) and [Amazon Route 53 DNS resolver query logs](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-query-logs.html) for all VPCs
- Enable Amazon S3 data events in CloudTrail to monitor S3 object level events (If a high volume of S3 data events is expected, data events can be enabled in a separate trail so they can be searched seperately)
- Enable VPC Flow Logs with a custom field configuration including [all available fields through v5](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html#flow-logs-fields). 


**WARNING:** AWS Security Analytics Bootstrap expects VPC Flow Log fields to be in exactly this order (specifically for custom configurations): 

```${version} ${account-id} ${interface-id} ${srcaddr} ${dstaddr} ${srcport} ${dstport} ${protocol} ${packets} ${bytes} ${start} ${end} ${action} ${log-status} ${vpc-id} ${subnet-id} ${instance-id} ${tcp-flags} ${type} ${pkt-srcaddr} ${pkt-dstaddr} ${region} ${az-id} ${sublocation-type} ${sublocation-id} ${pkt-src-aws-service} ${pkt-dst-aws-service} ${flow-direction} ${traffic-path}```

AWS Security Analytics Bootstrap will still work for existing VPC Flow Log configurations which only include the default (v2) field configuration: 

```${version} ${account-id} ${interface-id} ${srcaddr} ${dstaddr} ${srcport} ${dstport} ${protocol} ${packets} ${bytes} ${start} ${end} ${action} ${log-status}```

as long as the fields are in the same order, the additional fields at the end would simply appear empty.  If existing VPC Flow Logs need to be supported that include fields in a different order, then the order of the VPC Flow Logs table fields would need to be updated to be in the same order in the [AWS Security Analytics Bootstrap Infrastructure CloudFormation Template](../../AthenaBootstrap/cfn/Athena_infra_setup.yml) or the [VPC Flow Log Create Table Statement](AthenaBootstrap/sql/ddl/create_tables/create_vpcflowlog_table.sql).

### 1.2 Determine Whether To Deploy In The Same Account Or Cross-account
The next step is to determine what account AWS Security Analytics Bootstrap will be deployed in.  If there's only a single AWS account the the choice is simple, however if it will be deployed in a multi-account environment (e.g. [AWS Control Tower](https://aws.amazon.com/controltower)) AWS Security Analytics Bootstrap can be deployed in different account than the logs such as the Audit or Security accounts.  If AWS Security Analytics Bootstrap will be deployed in the same account as your logs then you can skip the rest of this section, otherwise if AWS Security Analytics Bootstrap will be deployed in a different account than your logs are stored in please complete the following steps:
- Ensure that each of the S3 buckets containing the AWS service logs allows the Athena role(s)/user(s) to read the S3 bucket and its log objects from the account AWS Security Analytics Bootstrap will be deployed in.  The Athena documentation includes some [example cross-account configurations](https://docs.aws.amazon.com/athena/latest/ug/cross-account-permissions.html) and the example below is currently the least permissions required:
```
        "Action": [
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket"
        ],
        "Effect": "Allow",
        "Resource": [
            arn:aws:s3:::BUCKET_NAME,
            arn:aws:s3:::BUCKET_NAME/*
        ],
        "Principal": {
            "AWS": [
                "arn:aws:iam::111122223333:role/ROLENAME"
            ]
        }
```

### 1.3 Ensure Athena Role(s)/User(s) Can Access Encrypted S3 Buckets
If the source *S3 buckets* that AWS service logs are stored in are encrypted using KMS follow the [examples provided in cross-account configuration documentation](https://docs.aws.amazon.com/athena/latest/ug/cross-account-permissions.html) to ensure that the Athena role(s)/user(s) have the appropriate KMS permissions to decrypt objects from the encrypted S3 buckets.  AWS IAM principal(s) that will be used to submit Athena queries will need to have permissions for `kms:Decrypt` and `kms:DescribeKey` in their IAM policy and the associated KMS key policy will need to grant them the same access.

### 1.4 Ensure Athena Role(s)/User(s) Can Decrypt Encrypted AWS Service Logs
Some AWS Service Logs can be configured to be encrypted using KMS at an object level in addition to S3 bucket encryption (e.g. [AWS Cloudtrail](https://docs.aws.amazon.com/kms/latest/developerguide/logging-using-cloudtrail.html)).  AWS IAM principal(s) that will be used to submit Athena queries will need to have permissions for `kms:Decrypt` and `kms:DescribeKey` in their IAM policy and the associated KMS key policy will need to grant them the same access.

### 1.5 Ensure That The Service Log Objects Are Owned By The S3 Bucket Owner
For cross-account deployments it will be required that the AWS service log objects stored in S3 belong to the bucket owner (e.g. the same account as the bucket is in).  By default, even with the `bucket-owner-full-control` ACL applied, objects written by another AWS principal (e.g. the logging service) will still be owned by that principal.  While the bucket owner will have full control, they will not be able to delegate access to another account (such as cross-account to an Athena user) unless they have ownership of the object.  More about object ownership can be found in this [Amazon S3 documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/about-object-ownership.html).  To configure the bucket owner as the owner of all objects going forward enable `bucket owner preferred` described in this `S3 documentation`(https://docs.aws.amazon.com/AmazonS3/latest/userguide/about-object-ownership.html#enable-object-ownership).  To update the ownership of objects already stored in the S3 bucket, the `bucket owner preferred` setting should be enabled then each object will need to be overwritten (e.g. recursively copy objects in the bucket to the same path in the same bucket, similar to what's described in this [knowledge center article](https://aws.amazon.com/premiumsupport/knowledge-center/s3-object-change-anonymous-ownership/)).  Full instructructions to update existing object ownership is out of scope for this project, please contact AWS Customer Support if you need assistance.

### 1.6 Determine Whether To Create A New S3 Bucket For The Athena Query Output Or Use An Existing S3 Bucket
Amazon Athena automatically stores [query results and metadata information for each query that runs](https://docs.aws.amazon.com/athena/latest/ug/querying.html) in a query result location that you can specify in Amazon S3.  An existing S3 bucket can be used or a new S3 bucket can be created to store the resulting Athena output files.  If an existing S3 bucket is used to store the Athena output files, it's recommended to create a unique prefix (e.g. /athena ) to keep the resulting output better organized and enable specific access policies if desired.  It is also  recommended that the output S3 bucket is in the same region as AWS Security Analytics Bootstrap will be deployed, if possible, to provide the best output performance.

### 1.7 Document All Required Parameters
In preparation to deploy AWS Security Analytics Bootstrap, document the following values which will be required as parameters to deploy the CloudFormation stack(s):

**AWS Security Analytics Bootstrap IAM CloudFormation Template (optional)**

 Parameter | Description | Example 
|-----|-----|-----| 
 AWS Source Log Location(s) |  Full path(s) for logs Athena will query in the form '<bucket_name>/<optional_prefix>/AWSLogs/' (comma separated, no spaces between values) | `bucket_name/prefix/AWSLogs/,bucket_name2/prefix2/AWSLogs/` |  
 Athena Output Location |  Full path for Athena output in the form '<bucket_name>/<optional_prefix>/' | `query_history_bucket/optional_prefix/`
 All S3 Bucket Names | The name of all buckets, including log buckets and Athena output bucket (comma separated, no spaces between values) | `log_bucket_1,log_bucket_2,output_bucket`

 **AWS Security Analytics Bootstrap CloudFormation Infrastructure Template**

 Parameter | Description | Example 
|-----|-----|-----| 
Athena Workgroup Name | Name of the initial Athena Security Analysis workgroup to create | `SecurityAnalysis`
Athena Workgroup Description | Description of the initial Athena Security Analysis workgroup | `Security Analysis Athena Workgroup`
Athena Output Location | S3 path to write all query results, store 45-day query history, and created tables via queries | `s3://query_history_bucket/optional_prefix/`
Glue Database Name | Name of the Glue database to create, which will contain all security analysis tables created by this template (**cannot contain hyphen**) |`security_analysis`
Enable CloudTrail Glue Table | Do you want to create and enable a table for CloudTrail? | `Yes`
CloudTrail Glue Table Name | Name of the CloudTrail Glue table to create | `cloudtrail`
CloudTrail Source Location | S3 base path of CloudTrail logs to be included in the CloudTrail table (must end with /AWSLogs/ or /AWSLogs/<your_org_id>/ if you're using an organization trail) | `s3://<bucket>/<prefix>/AWSLogs/`
CloudTrail Projection Event Start Date | Start date for CloudTrail logs (replace <YYYY>/<MM>/<DD> with the first date of your logs, example: 2020/11/30) | `<YYYY>/<MM>/<DD>`
CloudTrail Account List |  Account(s) to include in the CloudTrail log table in a comma separated list with NO SPACES (example: "0123456789,0123456788,0123456777"); note that all accounts must be logging to the same source, with contents in {ParamVPCFlowSource}/AWSLogs/{account_number}/CloudTrail | `0123456789,0123456788,0123456777`
CloudTrail Region List | Regions to include in the CloudTrail log table in a comma separated list with NO SPACES; Include all regions for full coverage even if there are no logs currently in that region | `us-east-2,us-east-1,us-west-1,us-west-2,af-south-1,ap-east-1,ap-south-1,ap-northeast-3,ap-northeast-2,ap-southeast-1,ap-southeast-2,ap-northeast-1,ca-central-1,cn-north-1,cn-northwest-1,eu-central-1,eu-west-1,eu-west-2,eu-south-1,eu-west-3,eu-north-1,me-south-1,sa-east-1`
Enable VPC Flow Log Glue Table | Do you want to create and enable a table for VPC Flow Logs? | `Yes`
VPC Flow Log Glue Table Name | Name of the VPC Flow Log Glue table to create | `vpcflow`
VPC Flow Log Source Location | S3 base path of VPC Flow Logs to be included in the VPC flow table (must end with /AWSLogs/) | `s3://<bucket>/<prefix>/AWSLogs/`
VPC Flow Log Projection Event Start Date | Start date for VPC Flow Logs (replace <YYYY>/<MM>/<DD> with the first date of your logs, example: 2020/11/30) | `<YYYY>/<MM>/<DD>`
VPC Flow Log Account List |  Account(s) to include in the  VPC Flow Log log table in a comma separated list with NO SPACES (example: "0123456789,0123456788,0123456777"); note that all accounts must be logging to the same source, with contents in {ParamVPCFlowSource}/AWSLogs/{account_number}/vpcflowlogs | `0123456789,0123456788,0123456777`
VPC Flow Log Region List | Regions to include in the  VPC Flow Log log table in a comma separated list with NO SPACES; Include all regions for full coverage even if there are no logs currently in that region | `us-east-2,us-east-1,us-west-1,us-west-2,af-south-1,ap-east-1,ap-south-1,ap-northeast-3,ap-northeast-2,ap-southeast-1,ap-southeast-2,ap-northeast-1,ca-central-1,cn-north-1,cn-northwest-1,eu-central-1,eu-west-1,eu-west-2,eu-south-1,eu-west-3,eu-north-1,me-south-1,sa-east-1`
Enable Route53 DNS Resolver Logs Glue Table | Do you want to create and enable a table for Route53 DNS Resolver Logs? | `Yes`
Route53 DNS Resolver Logs Glue Table Name | Name of the Route53 DNS Resolver Logs Glue table to create | `r53dns`
Route53 DNS Resolver Logs Source Location | S3 base path of Route53 DNS Resolver logs to be included in the Route53 DNS Resolver table (must end with /AWSLogs/) | `s3://<bucket>/<prefix>/AWSLogs/`
Route53 DNS Resolver Logs Projection Event Start Date | Start date for Route53 DNS Resolver logs (replace <YYYY>/<MM>/<DD> with the first date of your logs, example: 2020/11/30) | `<YYYY>/<MM>/<DD>`
Route53 DNS Resolver Logs Account List |  Account(s) to include in the Route53 DNS Resolver Logs table in a comma separated list with NO SPACES (example: "0123456789,0123456788,0123456777"); note that all accounts must be logging to the same source, with contents in {ParamVPCFlowSource}/AWSLogs/{account_number}/vpcdnsquerylogs | `0123456789,0123456788,0123456777`
Route53 DNS Resolver Logs VPC List | VPC IDs to include in the Route53 DNS Resolver log table in a comma seperated list with NO SPACES; Include all VPC IDs for full coverage even if there are no logs currently in that VPC | `<vpc_id_1>,<vpc_id_2>,...`

## 2 Deploy AWS Security Analytics Bootstrap IAM CloudFormation Template (optional)

To deploy Amazon Athena admin and user roles following the principle of least privilege, the [AWS Security Analytics Bootstrap IAM CloudFormation Template](../../AthenaBootstrap/cfn/Athena_IAM_setup.yml) has been provided.  This step is optional as AWS customers who already have appropriate roles and policies to manage Athena and query AWS service logs for their organization may continue use those roles with AWS Security Analytics Bootstrap.  For customers who would like to create their own IAM policies, documentation on [Identity and Access Management in Athena](https://docs.aws.amazon.com/athena/latest/ug/security-iam-athena.html) is provided in the Amazon Athena service documentation.  Customer creating their own policies may want to review the admin and user policies provided in [AWS Security Analytics Bootstrap IAM CloudFormation Template](../../AthenaBootstrap/cfn/Athena_IAM_setup.yml) as a reference, which aim to provide policies with the least privilege required.

### 2.1 Update The AthenaAdmin And AthenaUser AssumeRole Policies In The CloudFormation Template

Before deploying [AWS Security Analytics Bootstrap IAM CloudFormation Template](../../AthenaBootstrap/cfn/Athena_IAM_setup.yml), the template must first be modified with the appropriate AssumeRole policies for AthenaAdmin and Athena users specified by in the template by the comment `# TODO: Replace this with the appropriate least-privilege AssumeRole policy for your organization`.  By default each role will currently deny all AssumeRole attempts, however this statement should be replaced before the template is deployed to be the appropriate least-privilege policy for the account in which it will be deployed.  For reference please review the [AWS Identity and Access Management documentation on AssumeRole policies](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_permissions-to-switch.html#roles-usingrole-createpolicy).

### 2.2 Further Restrict Privilege In CloudFormation Template As Desired

Currently the policies in the [AWS Security Analytics Bootstrap IAM CloudFormation Template](../../AthenaBootstrap/cfn/Athena_IAM_setup.yml) restrict certain actions to resources with the naming convention `Security*` or `security_*`.  This is to limit the roles' access to resources within these naming conventions in the event that there are other Amazon Athena or AWS Glue resources in the same account.  Both naming conventions were supported for flexibility, however strictly speaking only one is needed, or another naming convention could be used instead.  If desired, one of these naming conventions could be removed, or another naming convention could be used in their place.  Obviously, keep in mind when naming resources to always follow the specified naming convention to ensure these roles will have the appropriate access.

### 2.3 Create The IAM AWS Security Analytics Bootstrap IAM CloudFormation Stack

The updated [AWS Security Analytics Bootstrap IAM CloudFormation Template](../../AthenaBootstrap/cfn/Athena_IAM_setup.yml) can now be deployed to the target account via [console](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-using-console.html), [cli](https://docs.aws.amazon.com/cli/latest/reference/cloudformation/deploy/index.html), or as part of a custom change management pipeline (e.g. [Customizations for AWS Control Tower](https://aws.amazon.com/solutions/implementations/customizations-for-aws-control-tower/)).  The parameters documented in section 1.6 above will need to be provided, be sure to follow the formatting requirements exactly as specified for each parameter.

## 3 Test The AWS Security Analytics Bootstrap IAM Roles

Once the IAM AWS Security Analytics Bootstrap IAM CloudFormation Stack is deployed test to ensure that it's possible to assume the roles `AthenaSecurityAdminRole` and `AthenaSecurityAnalystRole` according to the updated AssumeRole policy.  While the Glue and Athena resources don't exist yet at this point, you may test to ensure that both the admin and user roles are able to access and read from the S3 buckets specified.  If the roles aren't able to read from the specified S3 buckets then the Athena queries won't work either, the prerequisites will need to be reviewed again to ensure that the user has access to any KMS keys required and that the user has access to the bucket and objects via bucket policy and object ownership.

## 4 Deploy AWS Security Analytics Bootstrap Infrastructure CloudFormation Stack
With all of the prerequisites met, the [AWS Security Analytics Bootstrap CloudFormation Template](../../AthenaBootstrap/docs/security_analytics_bootstrap_deployment_guide.md) can now be deployed to the target account via [console](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-using-console.html), [cli](https://docs.aws.amazon.com/cli/latest/reference/cloudformation/deploy/index.html), or as part of a custom change management pipeline (e.g. [Customizations for AWS Control Tower](https://aws.amazon.com/solutions/implementations/customizations-for-aws-control-tower/)).  The parameters documented in section 1.6 above will need to be provided, be sure to follow the formatting requirements exactly as specified for each parameter.  Also note that this stack will deploy the infrastructure in the same region that the stack is created, and it's recommended that 

## 5 Testing the AWS Security Analytics Bootstrap Infrastructure
Once the AWS Security Analytics Bootstrap Infrastructure CloudFormation Stack is deployed test to ensure that the environment is working as expected.  Test the following with the intended Athena Admin and User user(s)/role(s):

### 5.1 Setting the Athena Workgroup
The Athena Workgroup will determine where/how Athena output results are stored, track Athena query history of all users/roles using the current workgroup, and organize available saved queries.

- In the AWS Console access the `Athena` Service Console
- In the `Athena` Service Console Click on `Workgroup` (in the top bar)
- In the `Workgroups` view, click on the name of the workgroup (`SecurityAnalysis` by default or as specified in the CloudFormation Stack parameters) 
- With the Athena Workgroup selected click `View details`
- Verify that the `Query result location` is the desired location, that encryption is enabled under `Encrypt query results` (e.g. SSE_S3), and that `Override client-side settings` is Enabled
- Navigate back to the `Workgroups` view, and click on the name of the workgroup (`SecurityAnalysis` by default or as specified in the CloudFormation Stack parameters) 
- With the Athena Workgroup selected click `Switch workgroup`, this will set this workgroup as the active workgroup.  Note that Athena may ask for  acknowledgment to confirm the user's query output is being logged to the specified S3 location.

### 5.2 Setting the Glue Database
The Glue Database will determine what Glue tables are visible, and will be the default database for all queries which don't explicitly specify a database name.  For this reason it's recommended to ensure that users ensure that have selected the appropriate database prior to running queries.  This may need to be reset periodically if the user navigates away from the `Query editor` view.

- In the `Athena` Service Console Click on `Query editor` (in the top bar)
- On the left sidebar select the database from the drop down menu (`security_analysis` by default or as specified in the CloudFormation Stack parameters)
- Confirm that the expected AWS service log tables appear in the `Tables` section of the sidebar

### 5.3 Testing the Glue Tables
The Glue Tables will be the resource which Athena queries are typically run against.  When Athena queries specify Glue Tables in the `FROM`, these table definitions will determine how the data is interpreted at the time of the query.  It is important to understand that these tables determine the *representation* of the data in the query, it doesn't not change anything about underlying data itself.

- In the `Athena` Service Console Click on `Query editor`
- On the left sidebar select the database from the drop down menu (`security_analysis` by default or as specified in the CloudFormation Stack parameters)
- Confirm that the expected AWS service log tables appear in the `Tables` section of the sidebar
- For each table in the side bar:
  - Click on the 3-dots to the right of the table name and select `Preview table`
  - Verify that the preview executes successfully (10 rows should print out in the `Results` section)

If any of the table results don't appear, the prerequisites will need to be reviewed again to ensure that the user has access to any KMS keys required and that the user has access to the bucket and objects via bucket policy and object ownership.  If the prerequisites are met and the user has the ability to read the respective logs from the source S3 bucket, then review the parameters provided to the AWS Security Analytics Bootstrap Infrastructure CloudFormation Stack (specifically source locations) to ensure they match the target log configuration.

### 5.3 Testing the Saved Queries
Demo queries have been provided in the created Athena Workgroup under `Saved queries`.  It's recommended to use narrow partitioning, where possible, otherwise Athena will default to scanning all of the data in the table leading to higher cost and longer query times.  Demo queries have default partition constraints for account, region, and date which will need to be updated or removed according to the desired query parameters.  Demo queries may include partition constraints for account, region, and date which will need to be updated or removed according to the desired query parameters.  Additional saved queries can be added by any workgroup group user by selecting `Save as` under the query editor window.  

- In the `Athena` Service Console Click on `Saved queries`
- Click on a query name or description. This will open the `Query editor` view with the selected query in the query editor section 
- On the left sidebar select the database from the drop down menu (`security_analysis` by default or as specified in the CloudFormation Stack parameters)
- Review and update the query (specifically the `account_partition`, `region_partition`, and `date_partition` conditions)
- When ready, click the `Run query` button under the query editor section
- Ensure that the query completes successfully and review the results in the `Results`

## 6 Using AWS Security Analytics Bootstrap Infrastructure
Once the AWS Security Analytics Bootstrap Infrastructure is deployed, the Athena environment can be used to run queries against the respective tables created. It's beyond the scope of this project to explain how to use Athena, but there are a few other resources listed below which may be helpful:

### Resources from AWS
- [[Doc] Running SQL Queries Using Amazon Athena](https://docs.aws.amazon.com/athena/latest/ug/querying-athena-tables.html)
- [[Doc] Querying AWS Service Logs](https://docs.aws.amazon.com/athena/latest/ug/querying-AWS-service-logs.html)
- [[Blog] Analyze Security, Compliance, and Operational Activity Using AWS CloudTrail and Amazon Athena](https://aws.amazon.com/blogs/big-data/aws-cloudtrail-and-amazon-athena-dive-deep-to-analyze-security-compliance-and-operational-activity/)
- [[Blog] Athena Performance Tips](https://aws.amazon.com/blogs/big-data/top-10-performance-tuning-tips-for-amazon-athena/)
- [[Q&A] CTAS Bucketing Guidance](https://aws.amazon.com/premiumsupport/knowledge-center/set-file-number-size-ctas-athena/)

### Third Party Resources
- [[Guide] The Athena Guide](https://the.athena.guide/)
- [[Doc] Presto Documentation (current)](https://prestodb.io/docs/current/)
- [[Book] Presto The Definitive Guide (e-book)](https://www.starburst.io/wp-content/uploads/2020/04/OReilly-Presto-The-Definitive-Guide.pdf)
