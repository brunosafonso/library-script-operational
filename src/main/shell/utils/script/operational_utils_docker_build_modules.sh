#!/bin/sh

# Default script behavior.
set -o errexit
#set -o pipefail

# Default parameters.
DEBUG=false
DEBUG_OPT=
SERVICE_CONFIG_FILE=service.json
DOCKER_OPTIONS=
VERSION=latest
PULL="--pull"
PUSH=false

# For each.
while :; do
	case ${1} in
		
		# Debug.
		--debug)
			DEBUG=true
			DEBUG_OPT="--debug"
			;;

		# Base directory for images.
		-d|--base-directory)
			BASE_DIRECTORY=${2}
			shift
			;;

		# Service config file.
		-f|--service-config-file)
			SERVICE_CONFIG_FILE=${2}
			shift
			;;

		# Docker options.
		-o|--docker-options)
			DOCKER_OPTIONS=${2}
			shift
			;;
			
		# If pull should not be forced.
		--dont-pull)
			PULL=
			;;
			
		# If image should be pushed.
		-p|--push)
			PUSH=true
			;;

		# Version of the images.
		-v|--version)
			VERSION=${2}
			shift
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
${DEBUG} && echo "BASE_DIRECTORY=${BASE_DIRECTORY}"
${DEBUG} && echo "SERVICE_CONFIG_FILE=${SERVICE_CONFIG_FILE}"
${DEBUG} && echo "DOCKER_OPTIONS=${DOCKER_OPTIONS}"
${DEBUG} && echo "PUSH=${PUSH}"
${DEBUG} && echo "VERSION=${VERSION}"

# For each child directory.
for CURRENT_MODULE_DIRECTORY in ${BASE_DIRECTORY}/*/
do
	
	# If there is a service config.
	if [ -f ${CURRENT_MODULE_DIRECTORY}/${SERVICE_CONFIG_FILE} ]
	then
	
		# Gets the module name.
		MODULE_DOCKER_IMAGE=`jq -r '.container.docker.image' \
			< ${CURRENT_MODULE_DIRECTORY}/${SERVICE_CONFIG_FILE}`
		MODULE_DOCKER_IMAGE=`echo ${MODULE_DOCKER_IMAGE} | sed "s/\(.*\):[^:]*/\1/"`
		
		# Builds the current module.
		${DEBUG} && echo "Building module ${MODULE_DOCKER_IMAGE}"
		docker ${DOCKER_OPTIONS} build ${PULL} -t ${MODULE_DOCKER_IMAGE}:${VERSION} ${CURRENT_MODULE_DIRECTORY}
		
		# If push should also be made.
		if ${PUSH}
		then
		
			# Pushes the module.
			${DEBUG} && echo "Pushing module ${MODULE_DOCKER_IMAGE}"
			docker ${DOCKER_OPTIONS} push ${MODULE_DOCKER_IMAGE}:${VERSION}
		
		fi
		
	fi
	
done

