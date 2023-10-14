#/usr/bin/env bash

set -e
#set -x

if [[ -z "${AWS_ACCESS_KEY_ID}" || -z "${AWS_SECRET_ACCESS_KEY}" || -z "${AWS_SESSION_TOKEN}" ]]; then
	echo "The AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_SESSION_TOKEN Environment Variables must be set first to use this script".
	exit 1
fi

DEFAULT_REGION="eu-west-2"
DEFAULT_NEPTUNE_ENDPOINT="https://dev-neptune-cluster-a.cluster-chp1fpphk1ab.eu-west-2.neptune.amazonaws.com:8182"

function parse_args() {
	local args=("$@")

	for (( i = 0; i < ${#args[@]}; i++ )); do
		local key="${args[${i}]}"

		case ${key} in

			-r|--region)
				i=$((i+1))
				REGION="${args[${i}]}"
				;;

			-h|--help)
				HELP=true
				;;

			*)
				LOAD_ID="${args[${i}]}"
				;;
		esac
	done
}

function print_help() {
	echo "Usage: omg-check-neptune-load.sh [-rh] [--region eu-west-2] loadId"
	echo -e "\t-r|--region	The AWS region (default: $DEFAULT_REGION)."
	echo -e "\t--help   Flag to show this help text"
}

parse_args "$@"
if [[ -n "${HELP}" ]]; then
	print_help
	exit
fi

if [[ -z "${REGION}" ]]; then
	REGION="${DEFAULT_REGION}"
fi

if [[ -z "${LOAD_ID}" ]]; then
	echo "You must provide the 'loadId' from a previous request to Neptune to load data"
	exit 1
fi

LOAD_STATUS_RESPONSE="$(awscurl --region "${REGION}" --service neptune-db -X GET -H "Accept: application/json" "$DEFAULT_NEPTUNE_ENDPOINT/loader?loadId=${LOAD_ID}")"

STATUS="$(echo "${LOAD_STATUS_RESPONSE}" | jq -r .status)"

if [[ -z "${STATUS}" || "${STATUS}" == "null" ]]; then
	echo "An error occurred"
	echo "${LOAD_STATUS_RESPONSE}" | jq
	exit 2
else
	echo "Response: ${STATUS}"
	echo -e "\n"
	echo "${LOAD_STATUS_RESPONSE}" | jq
fi

