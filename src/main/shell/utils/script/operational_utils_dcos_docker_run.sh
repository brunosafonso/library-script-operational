#!/bin/sh

# Default script behavior.
set -o errexit
#set -o pipefail

# Default parameters.
DEBUG=false
DEBUG_OPT=
DETACH_OPT=-d
PROFILE_DIR=
DOCKER_OPTIONS=
CMD=

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

		# Attached docker option.
		-a|--docker-attached)
			DETACH_OPT=
			;;

		# Docker options.
		-o|--docker-options)
			DOCKER_OPTIONS=${2}
			shift
			;;

		# Other option.
		?*)
			CMD="${CMD} ${1}"
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
# Environment variables.
ENV_VARIABLES=""
for ENV_VARIABLE in `jq -c -r '.env | keys[]' <<EOF
${SERVICE_CONFIG}
EOF
`
do
	ENV_VARIABLES="${ENV_VARIABLES} -e ${ENV_VARIABLE}=`jq -r \".env.${ENV_VARIABLE}\" <<EOF
${SERVICE_CONFIG}
EOF
`"
done

# Resources.
RESOURCES_LIMIT="--memory=`jq -r '.mem'<<EOF
${SERVICE_CONFIG}
EOF
`M --cpus=`jq -r '.cpus' <<EOF
${SERVICE_CONFIG}
EOF
`"

# Docker parameters.
PARAMS=""
for PARAM in `jq -c '.container.docker.parameters[]' <<EOF
${SERVICE_CONFIG}
EOF
`
do
	PARAMS="${PARAMS} --`jq -r '.key' <<EOF
${PARAM}
EOF
` `jq -r '.value' <<EOF
${PARAM}
EOF
`"
done


# Runs the docker command.
${DEBUG} && echo "docker run ${CONTAINER_NAME} ${ENV_VARIABLES} ${RESOURCES_LIMIT} ${PARAMS} ${DOCKER_OPTIONS} ${DETACH_OPT} ${IMAGE_NAME} ${CMD}"
docker run ${CONTAINER_NAME} ${ENV_VARIABLES} ${RESOURCES_LIMIT} ${PARAMS} ${DOCKER_OPTIONS} ${DETACH_OPT} ${IMAGE_NAME} ${CMD}
