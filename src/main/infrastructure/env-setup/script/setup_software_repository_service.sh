#!/bin/sh

# Default script behavior.
set -o errexit
#set -o pipefail

# Debug is disabled by default.
DEBUG=false
DEBUG_OPT=

# Default parameters.
WORK_DIRECTORY=/project
CONTAINER_IMAGE=coldis/software-repository-service
DCOS_CONFIG_FILE=dcos_cli.properties
DCOS_TEMP_SERVICE_FILE=temp-service.json

# For each argument.
while :; do
	case ${1} in
		
		# Debug argument.
		--debug)
			DEBUG=true
			DEBUG_OPT="--debug"
			;;
			
		# Work directory.
		-d|--work-directory)
			WORK_DIRECTORY=${2}
			shift
			;;

		# DCOS service file argument.
		-c|--dcos-config-file)
			DCOS_CONFIG_FILE=${2}
			shift
			;;

		# Unkown option.
		?*)
			printf 'WARN: Unknown option (ignored): %s\n' "${1}" >&2
			;;

		# No more options.
		*)
			break

	esac 
	shift
done

# Reads the service file to a temp file.
rm -f ${WORK_DIRECTORY}/${DCOS_TEMP_SERVICE_FILE}
touch ${WORK_DIRECTORY}/${DCOS_TEMP_SERVICE_FILE}
while read -r DCOS_TEMP_SERVICE_LINE
do
	echo "${DCOS_TEMP_SERVICE_LINE}" >> ${WORK_DIRECTORY}/${DCOS_TEMP_SERVICE_FILE}
done

# Using unavaialble variables should fail the script.
set -o nounset

# Enables interruption signal handling.
trap - INT TERM

# Print arguments if on debug mode.
${DEBUG} && echo "Running 'production_setup_software_repository_service'"
${DEBUG} && echo "WORK_DIRECTORY=${WORK_DIRECTORY}"
${DEBUG} && echo "DCOS_CONFIG_FILE=${DCOS_CONFIG_FILE}"
${DEBUG} && echo "DCOS_TEMP_SERVICE_FILE=${DCOS_TEMP_SERVICE_FILE}"

# Updates the service config.
DCOS_SERVICE=`jq ".container.docker.image = \"${CONTAINER_IMAGE}\"" < ${DCOS_TEMP_SERVICE_FILE}`
echo "${DCOS_SERVICE}" > ${WORK_DIRECTORY}/${DCOS_TEMP_SERVICE_FILE}
${DEBUG} && echo "${DCOS_SERVICE}"

# Create internal access control service.
docker run --rm -i \
	--env-file ${WORK_DIRECTORY}/${DCOS_CONFIG_FILE}\
	coldis/dcos-cli \
	"dcos_deploy_marathon ${DEBUG_OPT}" < ${DCOS_TEMP_SERVICE_FILE}
rm -f ${WORK_DIRECTORY}/${DCOS_TEMP_SERVICE_FILE}

