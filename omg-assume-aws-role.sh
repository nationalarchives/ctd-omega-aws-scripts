#!/usr/bin/env bash

#set -e
#set -x

function parse_args() {
	local args=("$@")

	for (( i = 0; i < ${#args[@]}; i++ )); do
		local key="${args[${i}]}"

		case ${key} in

			-e|--setup-env)
				SETUP_ENV=true
				;;

			-h|--help)
				HELP=true
				;;

			*)
				ROLE_NAME="${args[${i}]}"
				;;
		esac
	done
}

function print_help() {
	echo "Usage: omg-assume-aws-role.sh [-eh] [--setup-env] [role]"
	echo -e "\t-e|--setup-env	Setup the Environment Variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_SESSION_TOKEN. NOTE that the script must be invoked via 'source' (e.g. 'source omg-assume-aws-role.sh -e') to be able to affect the parent environment!"
	echo -e "\t--help		Flag to show this help text"
}

parse_args "$@"
if [[ -n "${HELP}" ]]; then
	print_help
	exit
fi

if [[ -n "${SETUP_ENV}" ]]; then
	unset AWS_ACCESS_KEY_ID
	unset AWS_SECRET_ACCESS_KEY
	unset AWS_SESSION_TOKEN
fi

if [[ -n "${ROLE_NAME}" ]]; then
	ROLE_ARN="arn:aws:iam::320289993971:role/${ROLE_NAME}"
else
	EC2_INSTANCE_ROLE_NAME="puppet/$(hostname --short)_ec2_role"
	echo "Using default EC2 instance role: ${EC2_INSTANCE_ROLE_NAME}"
	ROLE_ARN="arn:aws:iam::320289993971:role/${EC2_INSTANCE_ROLE_NAME}"
fi

ASSUME_ROLE_RESPONSE=$(aws sts assume-role --duration-seconds 1800 --role-session-name AWSCLI-Session --role-arn "${ROLE_ARN}")

echo "Assumed role: ${ROLE_ARN}"

AWS_ACCESS_KEY_ID="$(echo "${ASSUME_ROLE_RESPONSE}" | jq -r .Credentials.AccessKeyId)"
AWS_SECRET_ACCESS_KEY="$(echo "${ASSUME_ROLE_RESPONSE}" | jq -r .Credentials.SecretAccessKey)"
AWS_SESSION_TOKEN="$(echo "${ASSUME_ROLE_RESPONSE}" | jq -r .Credentials.SessionToken)"

if [[ -n "${SETUP_ENV}" ]]; then
	export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
	export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
	export AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN}"
	echo "Setup Environment OK"
else
	echo -e "\tAccessKeyId: ${AWS_ACCESS_KEY_ID}"
	echo -e "\tSecretAccessKey: ${AWS_SECRET_ACCESS_KEY}"
	echo -e "\tSessionToken: ${AWS_SESSION_TOKEN}"
fi

