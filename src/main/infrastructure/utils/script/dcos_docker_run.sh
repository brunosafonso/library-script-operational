#!/bin/sh

# Default script behavior.
set -o errexit
#set -o pipefail

# Debug is disabled by default.
DEBUG=false
DEBUG_OPT=

# Default parameters.
PROFILE_DIR=
DOCKER_OPTIONS=

# For each.
while :; do
	case ${1} in
		
		# Debug.
		--debug)
			DEBUG=true
			DEBUG_OPT="--debug"
			;;

		# Serice config directory.
		-d|--service-config-dir)
			SERVICE_CONFIG_DIR=${2}
			shift
			;;

		# Service config file.
		-f|--service-config-file)
			SERVICE_CONFIG_FILE=${2}
			shift
			;;

		# Profile file.
		-p|--profile-dir)
			PROFILE_DIR=${2}
			shift
			;;

		# Docker options.
		-o|--docker-options)
			DOCKER_OPTIONS=${2}
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
${DEBUG} && echo  "Running 'dcos-docker-run'"
${DEBUG} && echo  "SERVICE_CONFIG_DIR=${SERVICE_CONFIG_DIR}"
${DEBUG} && echo  "SERVICE_CONFIG_FILE=${SERVICE_CONFIG_FILE}"
${DEBUG} && echo  "PROFILE_DIR=${PROFILE_DIR}"
${DEBUG} && echo  "DOCKER_OPTIONS=${DOCKER_OPTIONS}"

# If no profile is set.
if [ "${PROFILE_DIR}" = "" ]
then
	# Service config is the config file content.
	SERVICE_CONFIG=`cat ${SERVICE_CONFIG_DIR}/${SERVICE_CONFIG_FILE}`
# If a profile is set.
else 
	# Merges the main file with the profile file.
	SERVICE_CONFIG=`jq -s '.[0] * .[1]' \
		${SERVICE_CONFIG_DIR}/${SERVICE_CONFIG_FILE} ${SERVICE_CONFIG_DIR}/${PROFILE_DIR}/${SERVICE_CONFIG_FILE}`
fi

# Gets the docker container config.
CONTAINER_NAME="--name `jq -r '.id' <<EOF
${SERVICE_CONFIG}
EOF
`"
IMAGE_NAME="`jq -r '.container.docker.image' <<EOF
${SERVICE_CONFIG}
EOF
`"
ENV_VARIABLES=""
for ENV_VARIABLE in `jq -r '.env | keys[]' <<EOF
${SERVICE_CONFIG}
EOF
`
do
	ENV_VARIABLES="${ENV_VARIABLES} -e ${ENV_VARIABLE}=`jq \".env.${ENV_VARIABLE}\" <<EOF
${SERVICE_CONFIG}
EOF
`"
done
PORT_MAPPINGS=""
for PORT_MAPPING in `jq -c '.container.portMappings[]' <<EOF
${SERVICE_CONFIG}
EOF
`
do
	PORT_MAPPINGS="${PORT_MAPPINGS} -p `jq -r .hostPort'' <<EOF
${PORT_MAPPING}
EOF
`:`jq -r '.containerPort'<<EOF
${PORT_MAPPING}
EOF
`"
done
RESOURCES_LIMIT="--memory=`jq -r '.mem'<<EOF
${SERVICE_CONFIG}
EOF
`M --cpus=`jq -r '.cpus' <<EOF
${SERVICE_CONFIG}
EOF
`"

# Runs the docker command.
${DEBUG} && echo "docker run ${CONTAINER_NAME} ${ENV_VARIABLES} ${PORT_MAPPINGS} ${RESOURCES_LIMIT} -d ${IMAGE_NAME}"
docker run ${CONTAINER_NAME} ${ENV_VARIABLES} ${PORT_MAPPINGS} ${RESOURCES_LIMIT} ${DOCKER_OPTIONS} -d ${IMAGE_NAME}


