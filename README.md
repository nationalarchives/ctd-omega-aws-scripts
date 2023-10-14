# Various AWS Utility Scripts

Some small Bash scripts for simplifying working with AWS.

## Requirements

1. AWS CLI - https://aws.amazon.com/cli/
2. awscurl - https://github.com/okigan/awscurl
3. jq - https://jqlang.github.io/jq/

## The Scripts

All scripts have a `--help` (or `-h`) parameter which you may use to find out how to use them.

### 1. `omg-assume-aws-role.sh`

A small wrapper around `aws sts assume-role`, when run via `source` and appended with the `--setup-env` argument, it will set the environment variables `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN` with the details of the assumed role for you.

### 2. `omg-neptune-load.sh`

Instructs Neptune to load data from an AWS S3 bucket.

### 3. `omg-check-neptune-load.sh`

Checks on the status of (a previous request to) Neptune loading data from an S3 bucket.

## Examples

### 1. Loading data into Neptune via S3

Let's say we want to load the following Turtle file (`adamretter.ttl`) into Neptune:

```ttl
@prefix foaf: <http://xmlns.com/foaf/0.1/> .

<http://adamretter.org.uk>
    a foaf:Person ;
    foaf:firstName "Adam" ;
    foaf:family_name "Retter" ;
    foaf:mbox <mailto:adam.retter@googlemail.com> ;
    foaf:homepage <http://www.adamretter.org.uk.uk>
    .
```

The steps needed to acomplish that could look like:

If you first need to connect to a Development Workstation in the Omega environment (optional), make sure you have your VPN connected, and then:
```bash
ssh ec2-user@dev-workstation-1.omg.catalogue.nationalarchives.gov.uk
```

To load the data into Neptune via S3 (assuming the data is stored in `/tmp/adamretter.ttl`):

```bash
source ~/bin/omg-assume-aws-role.sh --setup-env
aws s3 cp /tmp/adamretter.ttl s3://ctd-neptune-loader/neptune/loader/
~/bin/omg-neptune-load.sh adamretter.ttl
```

The above commands should produce output like the following:
```
Using default EC2 instance role: puppet/dev-workstation-1_ec2_role
Assumed role: arn:aws:iam::320289993971:role/puppet/dev-workstation-1_ec2_role
Setup Environment OK

upload: ../../tmp/adamretter.ttl to s3://ctd-neptune-loader/neptune/loader/adamretter.ttl

Attempting to load 's3://ctd-neptune-loader/neptune/loader/adamretter.ttl' to: https://dev-neptune-cluster-a.cluster-chp1fpphk1ab.eu-west-2.neptune.amazonaws.com:8182 ...
Response: 200 OK
	loadId: a9bf249a-7a23-4783-8eb2-d047d36f3671
```

You can then check on the status of the upload by using `omg-check-neptune-load.sh` with the `loadId` value from the output above, for example:
```bash
~/bin/omg-check-neptune-load.sh a9bf249a-7a23-4783-8eb2-d047d36f3671
```

The above command should produce output like the following:
```
Response: 200 OK


{
  "status": "200 OK",
  "payload": {
    "feedCount": [
      {
        "LOAD_COMPLETED": 1
      }
    ],
    "overallStatus": {
      "fullUri": "s3://ctd-neptune-loader/neptune/loader/adamretter.ttl",
      "runNumber": 1,
      "retryNumber": 2,
      "status": "LOAD_COMPLETED",
      "totalTimeSpent": 3,
      "startTime": 1697299940,
      "totalRecords": 5,
      "totalDuplicates": 0,
      "parsingErrors": 0,
      "datatypeMismatchErrors": 0,
      "insertErrors": 0
    }
  }
}
```
