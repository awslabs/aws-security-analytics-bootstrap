# Amazon Security Lake OCSF Queries

This directory contains sample security analytics queries for the new [Amazon Security Lake](https://w.amazon.com/bin/view/SecurityLake/) service.  Amazon Security Lake is a new automated security data lake service that allows customers to aggregate, manage, and derive value from their security related log and event data. Amazon Security Lake automates the central management of security data, normalizing it into the open-source security schema [OCSF](https://github.com/ocsf).  OCSF was [co-initiated by AWS and developed in collaboration with other industry leaders](https://aws.amazon.com/blogs/security/aws-co-announces-release-of-the-open-cybersecurity-schema-framework-ocsf-project/) to enable security use cases such as incident response and security data analytics.

These queries were originally developed for the AWS Customer Incident Response Team for the [AWS Security Analytics Bootstrap](https://github.com/awslabs/aws-security-analytics-bootstrap/blob/main/LICENSE) project and were converted into the normalized OSCF log format used by Amazon Security Lake.

## Amazon Security Lake Demo Queries

 AWS Service Log | Demo Query Link
------|------|
All Queries Combined | [all demo queries](./ocsf/amazon_security_lake_queries_all.md)
[AWS CloudTrail Management Events](https://docs.aws.amazon.com/security-lake/latest/userguide/internal-sources.html#cloudtrail-event-logs) | [cloudtrail management events demo queries](./ocsf/amazon_security_lake_queries_cloudtrail_management.md)
[AWS CloudTrail Lambda Data Events](https://docs.aws.amazon.com/security-lake/latest/userguide/internal-sources.html#cloudtrail-event-logs) | [cloudtrail lambda data events demo queries](./ocsf/amazon_security_lake_queries_cloudtrail_lambda.md)
[Amazon Virtual Private Cloud (VPC) Flow Logs](https://docs.aws.amazon.com/security-lake/latest/userguide/internal-sources.html#vpc-flow-logs) | [vpc flow demo queries](./ocsf/amazon_security_lake_queries_vpcflow.md)
[Amazon Route 53 DNS resolver query logs](https://docs.aws.amazon.com/security-lake/latest/userguide/internal-sources.html#route-53-logs) | [route 53 dns demo queries](./ocsf/amazon_security_lake_queries_route53.md)
[Security Hub Findings](https://docs.aws.amazon.com/security-lake/latest/userguide/internal-sources.html#security-hub-findings) | [security hub event demo queries](./ocsf/amazon_security_lake_queries_securityhub.md)

## Acknowledgment

Many thanks to support from:
- AWS Customer Incident Response Team
- Amazon Security Lake Product Team
- Anna McAbee
- Charles Roberts
- Marc Luescher
- Ross Warren
- Josh Pavel


## License

This project is licensed under the Apache-2.0 License.
