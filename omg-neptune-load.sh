#/usr/bin/env bash

set -e
#set -x

if [[ -z "${AWS_ACCESS_KEY_ID}" || -z "${AWS_SECRET_ACCESS_KEY}" || -z "${AWS_SESSION_TOKEN}" ]]; then
	echo "The AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_SESSION_TOKEN Environment Variables must be set first to use this script".
	exit 1
fi

DEFAULT_REGION="eu-west-2"
DEFAULT_S3_BUCKET="ctd-neptune-loader"
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

			-s|--s3-bucket)
				i=$((i+1))
				S3_BUCKET="${args[${i}]}"
				;;

			-h|--help)
				HELP=true
				;;

			*)
				S3_FILE="${args[${i}]}"
				;;
		esac
	done
}

function print_help() {
	echo "Usage: omg-neptune-load.sh [-rsh] [--region eu-west-2] [--s3-bucket ctd-neptune-loader] s3-file-path"
	echo -e "\t-r|--region	The AWS region (default: $DEFAULT_REGION)."
	echo -e "\t-s|--s3-bucket	The name of the S3 bucket to load from (default: $DEFAULT_S3_BUCKET)."
	echo -e "\ts3-file-path	The path to a file in the S3 bucket, if the path does not have a leading '/' character, then it will be prefixed with the path '/neptune/loader/'."

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
if [[ -z "${S3_BUCKET}" ]]; then
	S3_BUCKET="${DEFAULT_S3_BUCKET}"
fi

if [[ -z "${S3_FILE}" ]]; then
	echo "You must provide the path to a file within the S3 bucket to load"
	exit 1
fi

# NOTE(AR) If S3 file path is not absolute i.e. it starts with a `/`, then prefix it with `/neptune/loader/`
if [[ ! $S3_FILE = '/'* ]]; then
	S3_FILE="/neptune/loader/${S3_FILE}"
fi

S3_PATH="s3://${S3_BUCKET}${S3_FILE}"

UUID="$(uuid)"
LOAD_REQUEST_TEMP_FILENAME="${UUID}.request.json"
LOAD_REQUEST_TEMP_PATH="/tmp/${LOAD_REQUEST_TEMP_FILENAME}"
LOAD_RESPONSE_TEMP_FILENAME="${UUID}.response.json"
LOAD_RESPONSE_TEMP_PATH="/tmp/${LOAD_RESPONSE_TEMP_FILENAME}"

cat <<EOF > $LOAD_REQUEST_TEMP_PATH
{
  "source": "${S3_PATH}",
  "format": "turtle",
  "iamRoleArn": "arn:aws:iam::320289993971:role/neptune/neptune_loader_role",
  "region": "${REGION}"
}
EOF

echo "Attempting to load '${S3_PATH}' to: ${DEFAULT_NEPTUNE_ENDPOINT} ..."

awscurl --region "${REGION}" --service neptune-db -X POST -H "Content-Type: application/json" -H "Accept: application/json" -d "@${LOAD_REQUEST_TEMP_PATH}" "${DEFAULT_NEPTUNE_ENDPOINT}/loader" > $LOAD_RESPONSE_TEMP_PATH

STATUS="$(cat $LOAD_RESPONSE_TEMP_PATH | jq -r .status)"
LOAD_ID="$(cat $LOAD_RESPONSE_TEMP_PATH | jq -r .payload.loadId)"

if [[ -z "${STATUS}" || "${STATUS}" == "null" ]]; then
	echo "An error occurred"
	cat $LOAD_RESPONSE_TEMP_PATH | jq
	exit 2
else
	echo "Response: ${STATUS}"
	echo -e "\tloadId: ${LOAD_ID}"
fi

