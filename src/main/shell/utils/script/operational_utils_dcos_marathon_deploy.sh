#!/bin/sh

# Default script behavior.
set -o errexit
#set -o pipefail

# Default parameters.
DEBUG=false
DEBUG_OPT=
MODULES_FILE=modules.json
SERVICE_CONFIG_FILE=service.json
TEMP_SERVICE_CONFIG_FILE=temp-service.json
PROFILE_DIRECTORY=
PRE_DEPLOY_SCRIPT=pre_deploy.sh
POST_DEPLOY_SCRIPT=post_deploy.sh
DOCKER_OPTIONS=
VERSION=latest
PUSH=false

# For each.
while :; do
	case ${1} in
		
		# Debug.
		--debug)
			DEBUG=true
			DEBUG_OPT="--debug"
			;;

		# Base directory for modules.
		-d|--base-directory)
			BASE_DIRECTORY=${2}
			shift
			;;
			
		# Modules file.
		-m|--modules-file)
			MODULES_FILE=${2}
			shift
			;;

		# Service config file.
		-f|--service-config-file)
			SERVICE_CONFIG_FILE=${2}
			shift
			;;
			
		# Profile directory.
		-p|--profile)
			PROFILE_DIRECTORY=${2}
			shift
			;;

		# DCOS CLI container name.
		-c|--cli-container)
			CLI_CONTAINER=${2}
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
${DEBUG} && echo "Running 'operational_utils_dcos_marathon_deploy'"
${DEBUG} && echo "BASE_DIRECTORY=${BASE_DIRECTORY}"
${DEBUG} && echo "SERVICE_CONFIG_FILE=${SERVICE_CONFIG_FILE}"

# For each child directory.
for CURRENT_MODULE in `jq -rc ".[]" ${BASE_DIRECTORY}/${MODULES_FILE}`
do
	
	# Gets the module information.
	${DEBUG} && echo "CURRENT_MODULE=${CURRENT_MODULE}"
	CURRENT_MODULE_NAME=`echo ${CURRENT_MODULE} | jq -r ".name"`
	${DEBUG} && echo "CURRENT_MODULE_NAME=${CURRENT_MODULE_NAME}"
	CURRENT_MODULE_DIRECTORY=${BASE_DIRECTORY}/${CURRENT_MODULE_NAME}
	${DEBUG} && echo "CURRENT_MODULE_DIRECTORY=${CURRENT_MODULE_DIRECTORY}"
	CURRENT_MODULE_SERVICE_CONFIG=${SERVICE_CONFIG_FILE}
	${DEBUG} && echo "CURRENT_MODULE_SERVICE_CONFIG=${CURRENT_MODULE_SERVICE_CONFIG}"
	CURRENT_MODULE_PRE_DEPLOY_SCRIPT=`echo ${CURRENT_MODULE} | jq -r ".script.preDeploy"`
	CURRENT_MODULE_PRE_DEPLOY_SCRIPT=${CURRENT_MODULE_DIRECTORY}/`\
		[ -z ${CURRENT_MODULE_PRE_DEPLOY_SCRIPT} ] || \
		[ "${CURRENT_MODULE_PRE_DEPLOY_SCRIPT}" = "null" ] && \
		echo "${PRE_DEPLOY_SCRIPT}" || \
		echo "${CURRENT_MODULE_PRE_DEPLOY_SCRIPT}"`
	${DEBUG} && echo "CURRENT_MODULE_PRE_DEPLOY_SCRIPT=${CURRENT_MODULE_PRE_DEPLOY_SCRIPT}"
	CURRENT_MODULE_POST_DEPLOY_SCRIPT=`echo ${CURRENT_MODULE} | jq -r ".script.postDeploy"`
	CURRENT_MODULE_POST_DEPLOY_SCRIPT=${CURRENT_MODULE_DIRECTORY}/`\
		[ -z ${CURRENT_MODULE_POST_DEPLOY_SCRIPT} ] || \
		[ "${CURRENT_MODULE_POST_DEPLOY_SCRIPT}" = "null" ] && \
		echo "${POST_DEPLOY_SCRIPT}" || \
		echo "${CURRENT_MODULE_POST_DEPLOY_SCRIPT}"`
	${DEBUG} && echo "CURRENT_MODULE_POST_DEPLOY_SCRIPT=${CURRENT_MODULE_POST_DEPLOY_SCRIPT}"
	
	# Goes to the module directory.
	cd ${CURRENT_MODULE_DIRECTORY}
	
	# Exports variables to scripts.
	for ENV_VARIABLE in `cat ${CURRENT_MODULE_SERVICE_CONFIG} | jq -c -r '.env | keys[]'`
	do
		ENV_VARIABLE_VALUE="`cat ${CURRENT_MODULE_SERVICE_CONFIG} | jq -r ".env.${ENV_VARIABLE}"`"
		${DEBUG} && echo "Exporting ariable ${ENV_VARIABLE}=${ENV_VARIABLE_VALUE} for scripts."
		export ${ENV_VARIABLE}
	done
	${DEBUG} && echo "Exporting ariable CLI_CONTAINER=${CLI_CONTAINER} for scripts."
	export CLI_CONTAINER

	# If there is a pre deploy script.
	if [ -f ${CURRENT_MODULE_PRE_DEPLOY_SCRIPT} ]
	then
	
		# Runs the pre deploy script.
		${DEBUG} && echo "Running ${CURRENT_MODULE_PRE_DEPLOY_SCRIPT}"
		chmod +x ${CURRENT_MODULE_PRE_DEPLOY_SCRIPT} || true
		${CURRENT_MODULE_PRE_DEPLOY_SCRIPT}
	
	fi
		
	# If there is a service config.
	if [ -f ${CURRENT_MODULE_SERVICE_CONFIG} ]
	then
	
		# If no profile is set.
		if [ "${PROFILE_DIR}" = "" ]
		then
			# The temporary service config is the original one.
			cp ${CURRENT_MODULE_SERVICE_CONFIG} ${TEMP_SERVICE_CONFIG_FILE}
		# If a profile is set.
		else 
			# Merges the main file with the profile file into the temporary service file.
			jq -s '.[0] * .[1]' ${CURRENT_MODULE_SERVICE_CONFIG} \
				${PROFILE_DIRECTORY}/${CURRENT_MODULE_SERVICE_CONFIG} > ${TEMP_SERVICE_CONFIG_FILE}
		fi
	
		# Deploys the module.
		${DEBUG} && echo "docker exec -i ${CLI_CONTAINER} \
			dcos_deploy_marathon ${DEBUG_OPT} < ${TEMP_SERVICE_CONFIG_FILE}"
		docker exec -i ${CLI_CONTAINER} \
			dcos_deploy_marathon ${DEBUG_OPT} < ${TEMP_SERVICE_CONFIG_FILE}
			
		# Removes the temporary.
		rm -f ${TEMP_SERVICE_CONFIG_FILE}
		
	fi
	
	# If there is a post deploy script.
	if [ -f ${CURRENT_MODULE_POST_DEPLOY_SCRIPT} ]
	then
	
		# Runs the post deploy script.
		${DEBUG} && echo "Running ${CURRENT_MODULE_POST_DEPLOY_SCRIPT}"
		chmod +x ${CURRENT_MODULE_POST_DEPLOY_SCRIPT} || true
		${CURRENT_MODULE_POST_DEPLOY_SCRIPT}
	
	fi
	
	# Goes back to the base dir.
	cd ..
	
done

