#!/bin/sh

# Default script behavior.
set -o errexit
#set -o pipefail

# Default parameters.
DEBUG=false
DEBUG_OPT=
DETACH_OPT=-d
PROFILE_DIR=
ENV_TEMP_FILE=temp-env.properties
DOCKER_OPTIONS=
CMD=
IMAGE_VERSION=

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

		# Add docker image version.
		-i|--image-version)
			IMAGE_VERSION=${2}
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
${DEBUG} && echo "Running 'dcos-docker-run'"
${DEBUG} && echo "SERVICE_CONFIG_DIR=${SERVICE_CONFIG_DIR}"
${DEBUG} && echo "SERVICE_CONFIG_FILE=${SERVICE_CONFIG_FILE}"
${DEBUG} && echo "PROFILE_DIR=${PROFILE_DIR}"
${DEBUG} && echo "DOCKER_OPTIONS=${DOCKER_OPTIONS}"

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
CONTAINER_NAME="--name `echo ${SERVICE_CONFIG} | jq -r '.id'`"
IMAGE_NAME="`echo ${SERVICE_CONFIG} | jq -r '.container.docker.image'`"

if [ "${IMAGE_VERSION}" != "" ]
then
	IMAGE_NAME="`echo $IMAGE_NAME | sed "s@:.*@:${IMAGE_VERSION}@g"` || true"
fi

# Environment variables.
rm -f ${SERVICE_CONFIG_DIR}/${ENV_TEMP_FILE}
for ENV_VARIABLE in `echo ${SERVICE_CONFIG} | jq -c -r '.env | keys[]'`
do
	echo "${ENV_VARIABLE}=`echo ${SERVICE_CONFIG} | \
		jq -r ".env.${ENV_VARIABLE}"`" >> ${SERVICE_CONFIG_DIR}/${ENV_TEMP_FILE}
done

# Resources.
RESOURCES_LIMIT="--memory=`echo ${SERVICE_CONFIG} | jq -r '.mem'`\
M --cpus=`echo ${SERVICE_CONFIG} | jq -r '.cpus'`"

# Docker parameters.
PARAMS=""
for PARAM in `echo ${SERVICE_CONFIG} | jq -c '.container.docker.parameters[]'`
do
	PARAMS="${PARAMS} --`echo ${PARAM} | jq -r '.key'` `echo ${PARAM} | jq -r '.value'`"
done

# Runs the docker command.
${DEBUG} && echo "docker run ${CONTAINER_NAME} --env-file ${SERVICE_CONFIG_DIR}/${ENV_TEMP_FILE} \
	${RESOURCES_LIMIT} ${PARAMS} ${DOCKER_OPTIONS} ${DETACH_OPT} ${IMAGE_NAME} ${CMD}"
docker run ${CONTAINER_NAME} --env-file ${SERVICE_CONFIG_DIR}/${ENV_TEMP_FILE} \
	${RESOURCES_LIMIT} ${PARAMS} ${DOCKER_OPTIONS} ${DETACH_OPT} ${IMAGE_NAME} ${CMD}
