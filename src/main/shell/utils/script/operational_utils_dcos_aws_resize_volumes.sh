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
${DEBUG} && echo "Running 'dcos-aws-resize-volumes'"
${DEBUG} && echo "SERVICE_CONFIG_DIR=${SERVICE_CONFIG_DIR}"
${DEBUG} && echo "SERVICE_CONFIG_FILE=${SERVICE_CONFIG_FILE}"
${DEBUG} && echo "PROFILE_DIR=${PROFILE_DIR}"
${DEBUG} && echo "DOCKER_OPTIONS=${DOCKER_OPTIONS}"

