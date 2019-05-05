#!/bin/sh

# Default script behavior.
set -o errexit
#set -o pipefail

# Debug is disabled by default.
DEBUG=false
DEBUG_OPT=

# Default parameters.
PASSWORD_PATTERN="a-zA-Z0-9"
PASSWORD_SIZE=13
REPLACE_PATTERN="{{ PASSWORD_WILDCARD }}"

# For each argument.
while :; do
	case ${1} in
		
		# Debug argument.
		--debug)
			DEBUG=true
			DEBUG_OPT="--debug"
			;;

		# Random password pattern.
		-p|--pattern)
			PASSWORD_PATTERN=${2}
			shift
			;;

		# Random password size.
		-s|--size)
			PASSWORD_SIZE=${2}
			shift
			;;

		# Random password replace pattern.
		-r|--replace-pattern)
			REPLACE_PATTERN=${2}
			shift
			;;

		# Password file.
		-f|--password-file)
			PASSWORD_FILE=${2}
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
${DEBUG} && echo "Running 'random_password_replacer'"
${DEBUG} && echo "PASSWORD_PATTERN=${PASSWORD_PATTERN}"
${DEBUG} && echo "PASSWORD_SIZE=${PASSWORD_SIZE}"
${DEBUG} && echo "REPLACE_PATTERN=${REPLACE_PATTERN}"
${DEBUG} && echo "PASSWORD_FILE=${PASSWORD_FILE}"

# While there are passwords to be created.
while grep -q "${REPLACE_PATTERN}" ${PASSWORD_FILE}
do
	# Generates a new password and replaces it in the file.
	sed -i "0,/${REPLACE_PATTERN}/{s/${REPLACE_PATTERN}/`./random_password.sh`/}" ${PASSWORD_FILE}
done

