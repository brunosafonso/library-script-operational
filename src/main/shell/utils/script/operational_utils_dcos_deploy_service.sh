#!/bin/sh

# Default script behavior.
set -o errexit
#set -o pipefail

# Default parameters.
DEBUG=false
DEBUG_OPT=
CLI_CONTAINER=
MODULES_FILE=modules.json
INCLUDE_MODULES=
EXCLUDE_MODULES=
SERVICE_CONFIG_FILE=service.json
TEMP_SERVICE_CONFIG_FILE=temp-service.json
JOB_CONFIG_FILE=job.json
TEMP_JOB_CONFIG_FILE=temp-job.json
PROFILE_DIRECTORY=
PRE_DEPLOY_SCRIPT=pre_deploy.sh
POST_DEPLOY_SCRIPT=post_deploy.sh
FORCE_DEPLOYMENT=

# For each.
while :; do
	case ${1} in
		
		# Debug.
		--debug)
			DEBUG=true
			DEBUG_OPT="--debug"
			;;

		# DCOS CLI container name.
		-c|--cli-container)
			CLI_CONTAINER=${2}
			shift
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
			
		# Profile directory.
		-p|--profile)
			PROFILE_DIRECTORY=${2}
			shift
			;;

		# Force deployment.
		-f|--force)
			FORCE_DEPLOYMENT=--force
			;;

		# No more options.
		*)
			break

	esac 
	shift
done

# Container run prefix.
CONTAINER_RUN=
# If there is a CLI container to be used.
if [ ! -z "${CLI_CONTAINER}" ]
then
	# Updates the container run variable.
	CONTAINER_RUN="docker exec -i ${CLI_CONTAINER}"
fi

# Using unavaialble variables should fail the script.
set -o nounset

# Enables interruption signal handling.
trap - INT TERM

# Print arguments if on debug mode.
${DEBUG} && echo "Running 'operational_utils_dcos_marathon_deploy'"
${DEBUG} && echo "CLI_CONTAINER=${CLI_CONTAINER}"
${DEBUG} && echo "CONTAINER_RUN=${CONTAINER_RUN}"
${DEBUG} && echo "BASE_DIRECTORY=${BASE_DIRECTORY}"
${DEBUG} && echo "MODULES_FILE=${MODULES_FILE}"
${DEBUG} && echo "INCLUDE_MODULES=${INCLUDE_MODULES}"
${DEBUG} && echo "EXCLUDE_MODULES=${EXCLUDE_MODULES}"
${DEBUG} && echo "SERVICE_CONFIG_FILE=${SERVICE_CONFIG_FILE}"
${DEBUG} && echo "JOB_CONFIG_FILE=${JOB_CONFIG_FILE}"
${DEBUG} && echo "PROFILE_DIRECTORY=${PROFILE_DIRECTORY}"

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
	CURRENT_MODULE_JOB_CONFIG=${JOB_CONFIG_FILE}
	${DEBUG} && echo "CURRENT_MODULE_JOB_CONFIG=${CURRENT_MODULE_JOB_CONFIG}"
	CURRENT_MODULE_PRE_DEPLOY_SCRIPT=`echo ${CURRENT_MODULE} | jq -r ".script.preDeploy"`
	CURRENT_MODULE_PRE_DEPLOY_SCRIPT=`[ -z ${CURRENT_MODULE_PRE_DEPLOY_SCRIPT} ] || \
		[ "${CURRENT_MODULE_PRE_DEPLOY_SCRIPT}" = "null" ] && \
		echo "${PRE_DEPLOY_SCRIPT}" || \
		echo "${CURRENT_MODULE_PRE_DEPLOY_SCRIPT}"`
	${DEBUG} && echo "CURRENT_MODULE_PRE_DEPLOY_SCRIPT=${CURRENT_MODULE_PRE_DEPLOY_SCRIPT}"
	CURRENT_MODULE_POST_DEPLOY_SCRIPT=`echo ${CURRENT_MODULE} | jq -r ".script.postDeploy"`
	CURRENT_MODULE_POST_DEPLOY_SCRIPT=`[ -z ${CURRENT_MODULE_POST_DEPLOY_SCRIPT} ] || \
		[ "${CURRENT_MODULE_POST_DEPLOY_SCRIPT}" = "null" ] && \
		echo "${POST_DEPLOY_SCRIPT}" || \
		echo "${CURRENT_MODULE_POST_DEPLOY_SCRIPT}"`
	${DEBUG} && echo "CURRENT_MODULE_POST_DEPLOY_SCRIPT=${CURRENT_MODULE_POST_DEPLOY_SCRIPT}"

	# If the module should be deployed.
	if ([ -z "${INCLUDE_MODULES}" ] || \
			echo "${INCLUDE_MODULES}" | grep "^${CURRENT_MODULE_NAME}$") && 
		([ -z "${EXCLUDE_MODULES}" ] || \
			! echo "${EXCLUDE_MODULES}" | grep "^${CURRENT_MODULE_NAME}$")
	then
	
		# Goes to the module directory.
		cd ${CURRENT_MODULE_DIRECTORY}
		
		# If there is a service config.
		if [ -f ${CURRENT_MODULE_SERVICE_CONFIG} ]
		then
		
			# If no profile is set.
			if [ "${PROFILE_DIRECTORY}" = "" ]
			then
				# The temporary service config is the original one.
				cp ${CURRENT_MODULE_SERVICE_CONFIG} ${TEMP_SERVICE_CONFIG_FILE}
			# If a profile is set.
			else 
				# Merges the main file with the profile file into the temporary service file.
				jq -s '.[0] * .[1]' ${CURRENT_MODULE_SERVICE_CONFIG} \
					${PROFILE_DIRECTORY}/${CURRENT_MODULE_SERVICE_CONFIG} > ${TEMP_SERVICE_CONFIG_FILE}
			fi

			# Exports variables to scripts.
			for ENV_VARIABLE_NAME in `cat ${TEMP_SERVICE_CONFIG_FILE} | jq -c -r '.env | keys[]'`
			do
				ENV_VARIABLE_VALUE="`cat ${TEMP_SERVICE_CONFIG_FILE} | jq -r ".env.${ENV_VARIABLE_NAME}"`"
				${DEBUG} && echo "Exporting variable ${ENV_VARIABLE_NAME}=${ENV_VARIABLE_VALUE} for scripts."
				export ${ENV_VARIABLE_NAME}="${ENV_VARIABLE_VALUE}"
			done
			${DEBUG} && echo "Exporting variable CLI_CONTAINER=${CLI_CONTAINER} for scripts."
			export CLI_CONTAINER
			
		fi
	
		# If there is a job config.
		if [ -f ${CURRENT_MODULE_JOB_CONFIG} ]
		then
		
			# If no profile is set.
			if [ "${PROFILE_DIRECTORY}" = "" ]
			then
				# The temporary job config is the original one.
				cp ${CURRENT_MODULE_JOB_CONFIG} ${TEMP_JOB_CONFIG_FILE}
			# If a profile is set.
			else 
				# Merges the main file with the profile file into the temporary job file.
				jq -s '.[0] * .[1]' ${CURRENT_MODULE_JOB_CONFIG} \
					${PROFILE_DIRECTORY}/${CURRENT_MODULE_JOB_CONFIG} > ${TEMP_JOB_CONFIG_FILE}
			fi

			# Exports variables to scripts.
			for ENV_VARIABLE_NAME in `cat ${TEMP_JOB_CONFIG_FILE} | jq -c -r '.run.env | keys[]'`
			do
				ENV_VARIABLE_VALUE="`cat ${TEMP_JOB_CONFIG_FILE} | jq -r ".run.env.${ENV_VARIABLE_NAME}"`"
				${DEBUG} && echo "Exporting variable ${ENV_VARIABLE_NAME}=${ENV_VARIABLE_VALUE} for scripts."
				export ${ENV_VARIABLE_NAME}="${ENV_VARIABLE_VALUE}"
			done
			${DEBUG} && echo "Exporting variable CLI_CONTAINER=${CLI_CONTAINER} for scripts."
			export CLI_CONTAINER
			
		fi
	
		# If there is a pre deploy script.
		if [ -f ${CURRENT_MODULE_PRE_DEPLOY_SCRIPT} ]
		then
		
			# Runs the pre deploy script.
			${DEBUG} && echo "Running ${CURRENT_MODULE_PRE_DEPLOY_SCRIPT}"
			chmod +x ${CURRENT_MODULE_PRE_DEPLOY_SCRIPT} || true
			./${CURRENT_MODULE_PRE_DEPLOY_SCRIPT}
		
		fi
			
		# If there is a service config.
		if [ -f ${TEMP_SERVICE_CONFIG_FILE} ]
		then
		
			# Deploys the module.
			${DEBUG} && echo "${CONTAINER_RUN} dcos_deploy_marathon ${DEBUG_OPT} \
				< ${TEMP_SERVICE_CONFIG_FILE}"
			${CONTAINER_RUN} dcos_deploy_marathon ${FORCE_DEPLOYMENT} ${DEBUG_OPT} \
				< ${TEMP_SERVICE_CONFIG_FILE}
				
			# Removes the temporary.
			rm -f ${TEMP_SERVICE_CONFIG_FILE}
			
		fi
		
		# If there is a job config.
		if [ -f ${TEMP_JOB_CONFIG_FILE} ]
		then
		
			# Deploys the module.
			${DEBUG} && echo "${CONTAINER_RUN} dcos_deploy_job ${DEBUG_OPT} \
				< ${TEMP_JOB_CONFIG_FILE}"
			${CONTAINER_RUN} dcos_deploy_job ${DEBUG_OPT} \
				< ${TEMP_JOB_CONFIG_FILE}
				
			# Removes the temporary.
			rm -f ${TEMP_JOB_CONFIG_FILE}
			
		fi
		
		# If there is a post deploy script.
		if [ -f ${CURRENT_MODULE_POST_DEPLOY_SCRIPT} ]
		then
		
			# Runs the post deploy script.
			${DEBUG} && echo "Running ${CURRENT_MODULE_POST_DEPLOY_SCRIPT}"
			chmod +x ${CURRENT_MODULE_POST_DEPLOY_SCRIPT} || true
			./${CURRENT_MODULE_POST_DEPLOY_SCRIPT}
		
		fi
		
		# Goes back to the base dir.
		cd ..
		
	# If the module should not be deployed.	
	else 
		# Logs it.
		echo "Skipping module ${CURRENT_MODULE_NAME}"
	fi
	
done

