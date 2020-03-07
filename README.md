# aws-scripts
AWS scripts to make things a little easier.

## Bash scripts
### set_aws_mfa_auth.sh
Authenticates the AWS CLI using an MFA token to avoid needing to manually running the AWS STS command and setting the environmental variables. AWS CLI profiles are supported.

The script uses the AWS CLI commands to retrieve the ARN (serial number) of the MFA device configured for the AWS account. It then uses sts to authenticate using the provided 6 digit token and parses the response to set the environmental variables AWS_SECRET_ACCESS_KEY, AWS_ACCESS_KEY_ID, and AWS_SESSION_TOKEN so the AWS CLI commands will use the authentication token.

#### Requirements
- AWS CLI must already be installed and configured with at least one profile that requires MFA
- jq must be installed, it is used for parsing the JSON response from AWS CLI

#### Usage
Since the script is setting environmental variables, it must be ran with *source*. Two arguments are accepted, the profile name (if one is not provided, it will use the default profile) and the MFA token value.

Multiple profiles are supported by the script allowing the ability to switch between profiles once they have been authenticated without needing to authenticate again by running the script and only providing the profile name, or no arguments is switching back to the default profile.

##### Syntax
```bash
$ source ./set_aws_mfa_auth.sh [<profile_name>] [<mfa_token>]
```

##### Examples
```bash
# Authenticate to the default AWS CLI profile
$ source ./set_aws_mfa_auth.sh 123456

# Authenticate to the test AWS CLI profile
$ source ./set_aws_mfa_auth.sh test 123456

# Switch back to the default profile
$ source ./set_aws_mfa_auth.sh

# Switch back to the test profile
$ source ./set_aws_mfa_auth.sh test
```
