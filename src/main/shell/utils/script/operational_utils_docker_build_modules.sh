#!/bin/sh

# Default script behavior.
set -o errexit
#set -o pipefail

# Default parameters.
DEBUG=false
DEBUG_OPT=
MODULES_FILE=modules.json
INCLUDE_MODULES=
EXCLUDE_MODULES=
SERVICE_CONFIG_FILE=service.json
JOB_CONFIG_FILE=*job.json
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
		-s|--service-config-file)
			SERVICE_CONFIG_FILE=${2}
			shift
			;;
			
		# Service config file.
		-j|--job-config-file)
			JOB_CONFIG_FILE=${2}
			shift
			;;
			
		# Modules file.
		-m|--modules-file)
			MODULES_FILE=${2}
			shift
			;;
			
		# Modules to deploy.
		-i|--include-modules)
			INCLUDE_MODULES=`echo "${2}" | sed -e "s/[,;$]/\n/g"`
			shift
			;;

		# Modules not to deploy.
		-e|--exclude-modules)
			EXCLUDE_MODULES=`echo "${2}" | sed -e "s/[,;$]/\n/g"`
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
	[ "${2}" = "" ] || shift
done

# Using unavaialble variables should fail the script.
set -o nounset

# Enables interruption signal handling.
trap - INT TERM

# Print arguments if on debug mode.
${DEBUG} && echo "Running 'dcos-docker-run'"
${DEBUG} && echo "BASE_DIRECTORY=${BASE_DIRECTORY}"
${DEBUG} && echo "SERVICE_CONFIG_FILE=${SERVICE_CONFIG_FILE}"
${DEBUG} && echo "JOB_CONFIG_FILE=${JOB_CONFIG_FILE}"
${DEBUG} && echo "INCLUDE_MODULES=${INCLUDE_MODULES}"
${DEBUG} && echo "EXCLUDE_MODULES=${EXCLUDE_MODULES}"
${DEBUG} && echo "DOCKER_OPTIONS=${DOCKER_OPTIONS}"
${DEBUG} && echo "PUSH=${PUSH}"
${DEBUG} && echo "VERSION=${VERSION}"

# For each child directory.
for CURRENT_MODULE in `jq -rc ".[]" ${BASE_DIRECTORY}/${MODULES_FILE}`
do

	# Gets the module information.
	${DEBUG} && echo "CURRENT_MODULE=${CURRENT_MODULE}"
	CURRENT_MODULE_NAME=`echo ${CURRENT_MODULE} | jq -r ".name"`
	${DEBUG} && echo "CURRENT_MODULE_NAME=${CURRENT_MODULE_NAME}"
	CURRENT_MODULE_DIRECTORY=${BASE_DIRECTORY}/${CURRENT_MODULE_NAME}
	${DEBUG} && echo "CURRENT_MODULE_DIRECTORY=${CURRENT_MODULE_DIRECTORY}"
	
	# If the module should be built.
	if ([ -z "${INCLUDE_MODULES}" ] || [ "${INCLUDE_MODULES}" = "*" ] || \
			echo "${INCLUDE_MODULES}" | grep "^${CURRENT_MODULE_NAME}$") && 
		([ -z "${EXCLUDE_MODULES}" ] || [ "${EXCLUDE_MODULES}" != "*" ] || \
			! echo "${EXCLUDE_MODULES}" | grep "^${CURRENT_MODULE_NAME}$")
	then

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
		
		# For each job config.
		for CURRENT_MODULE_CURRENT_JOB_CONFIG in ${CURRENT_MODULE_DIRECTORY}/${JOB_CONFIG_FILE}
		do
			# If there is a job config.
			if [ -f ${CURRENT_MODULE_CURRENT_JOB_CONFIG} ]
			then
			
				# Gets the module name.
				MODULE_DOCKER_IMAGE=`jq -r '.run.docker.image' \
					< ${CURRENT_MODULE_CURRENT_JOB_CONFIG}`
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
		
	# If the module should not be built.	
	else 
		# Logs it.
		echo "Skipping module ${CURRENT_MODULE_NAME}"
	fi
	
done

