#!/bin/sh

# Default script behavior.
set -o errexit
#set -o pipefail

# Debug is disabled by default.
DEBUG=false
DEBUG_OPT=

# Default parameters.
CONTAINER_IMAGE=dinkel/openldap:2.4.40
TEMP_SERVICE_FILE=temp-service.json

# For each argument.
while :; do
	case ${1} in
		
		# Debug argument.
		--debug)
			DEBUG=true
			DEBUG_OPT="--debug"
			;;

		# DCOS service file argument.
		-c|--dcos-config-file)
			DCOS_CONFIG_FILE=${2}
			shift
			;;

		# DCOS config file argument.
		-s|--dcos-service-file)
			DCOS_SERVICE_FILE=${2}
			shift
			;;
			
		# Passwords file argument.
		-p|--secrets-file)
			SECRETS_FILE=${2}
			shift
			;;
			
		# Work directory.
		-d|--work-directory)
			WORK_DIRECTORY=${2}
			shift
			;;

		# Unkown option.
		-?*)
			printf 'WARN: Unknown option (ignored): %s\n' "${1}" >&2
			;;

		# No more options.
		*)
			break

	esac 
	shift
done

# Using unavaialble variables should fail the script.
set -o nounset

# Enables interruption signal handling.
trap - INT TERM

# Print arguments if on debug mode.
${DEBUG} && echo  "Running 'production_setup_internal_ac.sh'"
${DEBUG} && echo  "DCOS_CONFIG_FILE=${DCOS_CONFIG_FILE}"
${DEBUG} && echo  "DCOS_SERVICE_FILE=${DCOS_SERVICE_FILE}"
${DEBUG} && echo  "SECRETS_FILE=${SECRETS_FILE}"

# Makes sure the variables are available for the script.
set -a
. ${SECRETS_FILE}
set +a

# Gets the service config.
SERVICE_CONFIG=`envsubst < ${DCOS_SERVICE_FILE}`
SERVICE_CONFIG=`jq ".container.docker.image = \"${CONTAINER_IMAGE}\"" <<EOF
${SERVICE_CONFIG}
EOF
`

echo ${SERVICE_CONFIG} > ${WORK_DIRECTORY}/${TEMP_SERVICE_FILE}
${DEBUG} && echo ${SERVICE_CONFIG}

# Create internal access control service.
docker run --rm \
	--env-file ${DCOS_CONFIG_FILE}\
	-v ${WORK_DIRECTORY}:/project \
	dcos_deploy_marathon -f ${TEMP_SERVICE_FILE} ${DEBUG_OPT}

# rm -f ${WORK_DIRECTORY}/${TEMP_SERVICE_FILE}

