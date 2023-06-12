<!-- 
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: Apache-2.0 
-->

# Amazon Security Lake Example Queries

## Security Hub

### PREVIEW SECURITY HUB TABLE

**Query:** Preview first 10 rows with all fields, quick way to verify everything is setup correctly

```SQL
SELECT * 
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_sh_findings_1_0" 
LIMIT 10; 
```

### SECURITY HUB PARTITION TESTS 

> **NOTE:** if there are no partition constraints (accountid, region, or eventday) then by default ALL data will be scanned this could lead to costly query, always consider using at least one partition constraint.
> 
> Note that this is the case even if you have other constraints in a query (e.g. productname = 'Macice'), only constraints using partition fields (eventday, region, accountid) will limit the amount of data scanned.

**Query:** Preview first 10 rows with all fields, limited to a single account
```SQL
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_sh_findings_1_0"
WHERE accountid = '111122223333'
LIMIT 10;
```
**Query:** Preview first 10 rows with all fields, limited to multiple accounts
```SQL
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_sh_findings_1_0"
WHERE accountid in ('111122223333','444455556666','123456789012')
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited to a single region
```SQL
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_sh_findings_1_0"
WHERE region = 'us-east-1'
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited to multiple regions
```SQL
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_sh_findings_1_0"
WHERE region in ('us-east-1','us-east-2','us-west-2')
LIMIT 10;
```

**Query:** preview first 10 rows with all fields, limited to a certain date range
> NOTE: eventday format is 'YYYYMMDD' as a string
```SQL
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_sh_findings_1_0"
WHERE eventday >= '20230530'
AND eventday <= '20230631'
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited to the past 30 days (relative)
```SQL
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_sh_findings_1_0"
WHERE eventday >= date_format(date_add('day',-30,current_timestamp), '%Y%m%d')
LIMIT 10;
```

**Query:** Preview first 10 rows with all fields, limited by a combination of partition constraints
> NOTE: narrowing the scope of the query as much as possible will improve performance and minimize cost

```SQL
SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_sh_findings_1_0"
WHERE eventday >= '20230530'
AND eventday <= '20230631'
AND accountid = '111122223333'
AND region in ('us-east-1','us-east-2','us-west-2', 'us-west-2')
LIMIT 10;
```

## Security Hub Analysis Examples

### CONVERT UNIX TIMES TO DATE TIME GROUP (DTG)
The OSCF uses Unix times. You can convert these to a DTG which matches the Security Hub Finding Format

**Query** Convert the `finding.modified_time` column from Unix time to DTG and change the column name to `UpdatedAt`
```SQL
SELECT FROM_UNIXTIME(CAST(time AS DOUBLE)/1000.0) AS "Time"
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_sh_findings_1_0"
WHERE cloud.account_uid = '111122223333'
LIMIT 10;
```

### GET THE CONTROL ID
The data returned from Security Lake for a Security Hub Security Standard findings does not include the Security Standard Control Id, for example `SSM.1`. This can be obtained using `finding.title` which returns the full title and always begins with the Control Id, for example `ECR.2 ECR private repositories should have tag immutability configured`. 

**Query** Use `split_part()` to get the Control Id
```SQL
SELECT split_part(finding.title,' ',1) AS "ProductFields.ControlId"
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_sh_findings_1_0"
WHERE cloud.account_uid = '111122223333'
LIMIT 10;
```

In this example, `split_part()` is used with the selection of the title `finding.title` and uses the space `' '` to perfom the split and selects the first value `1`, this provides the ControlId, this value is given a column name of `ProductFields.ControlId` 

### CREATE OR REPLACE A VIEW
> NOTE: This view will be used for the following queries indicated by `FROM "sh_findings_view"` 

**Query** Create or replace a view called `sh_findings_view` which flattens the OCSF structure and maps column names to the AWS Security Hub Finding Format. This is just an example and not an exhaustive mapping of all the columns in the schema. 
```SQL
CREATE OR REPLACE VIEW "sh_findings_view" AS
SELECT
    metadata.product.version "SchemaVersion",
    metadata.product.feature.uid "GeneratorId",
    metadata.product.feature.name "ProductName",
    metadata.product.uid "ProductArn",
    metadata.product.vendor_name "CompanyName",
    metadata.product.name "Security Hub",
    metadata.version "Version",
    FROM_UNIXTIME(CAST(time AS DOUBLE)/1000.0) AS "Time",
    confidence "Confidence",
    severity "Severity",
    state "WorkflowStatus",
    cloud.account_uid "AWSAccountId",
    element_at(resources,1).type "ResourceType",
    element_at(resources,1).uid "ResourceId",
    element_at(resources,1).cloud_partition "ResourcePartition",
    element_at(resources,1).region "ResourceRegion",
    element_at(resources,1).details "resources.details",
    FROM_UNIXTIME(CAST(finding.created_time AS DOUBLE)/1000.0) AS "CreatedAt",
    finding.uid "Id",
    finding.desc "Description",
    finding.title "Title",
    split_part(finding.title,' ',1) AS "ProductFields.ControlId",
    FROM_UNIXTIME(CAST(finding.modified_time AS DOUBLE)/1000.0) AS "UpdatedAt",
    FROM_UNIXTIME(CAST(finding.first_seen_time AS DOUBLE)/1000.0) AS "FirstObservedAt",
    FROM_UNIXTIME(CAST(finding.last_seen_time AS DOUBLE)/1000.0) AS "LastObservedAt",
    element_at(finding.types,1) "Types",
    finding.remediation.desc "RecomendationText",
    finding.src_url "RecommendationUrl",
    compliance.status "ComplianceStatus",
    compliance.status_detail "Compliance.StatusReasons.Description",
    class_name "SecurityFinding",
    unmapped['Severity_Normalized'] "SeverityNormalized",
    unmapped['Severity_Original'] "SeverityOriginal",
    unmapped['FindingProviderFields'] "FindingProviderFields",
    region "Region",
    accountid "AccountId",
    eventday "EventDay"
FROM "amazon_security_lake_glue_db_us_east_1"."amazon_security_lake_table_us_east_1_sh_findings_1_0" 
```

### SELECT SECURITY FINDINGS FROM OTHER INTEGRATION PROVIDERS

Security Hub has integrations with lots of other AWS security services such as GuardDuty and Config. It also has integrations with other 3rd party security tools which can send findings to AWS Security Hub. You might want to select the findings from one or more security services. 

**Query** Select findings from Amazon Macie and only return the first 10 results using the `sh_findings_view`
```SQL
SELECT *
FROM "sh_findings_view"
    WHERE lower(ProductName) = 'macie'
    AND AWSAccountId = '111122223333'
LIMIT 10;
```
**Query** Select findings from Amazon Macie and AWS Config and only return 10 results

```SQL
SELECT *
FROM "sh_findings_view"
    WHERE lower(ProductName) in ('macie', 'config')
    AND AWSAccountId = '111122223333'
LIMIT 10;
```

***Query** Select `Config` findings from the `sh_findings_view` view 
```SQL
SELECT *, 
CASE
    WHEN lower(Severity) = 'high' THEN 1
    WHEN lower(Severity) = 'medium' THEN 2
    WHEN lower(Severity) = 'low' THEN 3
    ELSE 4
END as display_order
FROM "sh_findings_view"
WHERE lower(ProductName) = 'config'
AND AWSAccountId = '111122223333'
AND lower(WorkFlowStatus) = 'new'
AND lower(Severity) in ('high', 'medium', 'low')
ORDER BY display_order
LIMIT 10;
```
