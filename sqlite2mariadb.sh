#!/bin/bash

# This is a standalone script for converting a SQLite database schema to MySQL/MariaDB

# Based on https://github.com/home-assistant/core/blob/10a2fd7cb66c2d39c2652c9b85f78e89a0dfc7a9/homeassistant/components/recorder/db_schema.py#L425
function schema::type_map() {
	local table="$1"
	local field="$2"
	local type="$3"
	local not_null=false
	if [[ "${type}" =~ NOT\ NULL ]]; then
		not_null=true
	fi

	local extra=""

	case "${table}" in
		recorder_runs)
			case "${field}" in
				start|closed_incorrect|created)
					extra="NOT NULL";
					not_null=true
					;;
			esac
			;;
		schema_changes)
			case "${field}" in
				changed)
					extra="NOT NULL"
					not_null=true
					;;
			esac
			;;
		statistics_run)
			case "${field}" in
				start)
					extra="NOT NULL"
					not_null=true
					;;
			esac
			;;
		states)
			case "${field}" in
				# UNUSED_LEGACY_COLUMN
				entity_id|attributes|context_id|context_user_id|context_parent_id)
					type="char(0)"
					;;
				# UNUSED_LEGACY_DATETIME_COLUMN
				last_changed|last_updated)
					type="char(0)"
					;;
			esac
			;;
		events)
			case "${field}" in
				# UNUSED_LEGACY_COLUMN
				event_type|event_data|origin|context_id|context_user_id|context_parent_id)
					type="char(0)"
					;;
				# UNUSED_LEGACY_DATETIME_COLUMN
				time_fired)
					type="char(0)"
					;;
			esac
			;;
		statistics|statistics_short_term)
			case "${field}" in
				created|start|last_reset)
					type="char(0)"
					;;
			esac
			;;
	esac
	if ! ${not_null}; then
		extra="DEFAULT NULL"
	fi
	echo -n "${type}${extra:+ }${extra}"
}

function schema::convert() {
	local state='idle'
	local current_table=""

	echo 'SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";'
	echo 'START TRANSACTION;'
	echo 'SET FOREIGN_KEY_CHECKS = 0;'
	echo -e 'SET time_zone = "+00:00";\n'
	echo '/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;'
	echo '/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;'
	echo '/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;'
	echo -e '/*!40101 SET NAMES utf8mb4 */;\n\n'


	while IFS='' read -r line; do
		case "${state}" in
			"idle")
				if [[ "${line}" =~ ^CREATE\ TABLE\ .*\($ ]]; then
					# shellcheck disable=SC2016
					read -rd'(' _ _ current_table <<<"${line}"
					echo 'DROP TABLE IF EXISTS `'"${current_table}"'`;'
					echo 'CREATE TABLE `'"${current_table}"'` ('
					state="table"
				elif [[ "${line}" =~ ^CREATE(\ UNIQUE)?\ INDEX\  ]]; then
					# shellcheck disable=SC2016
					sed -E 's/"([^"]+)"/`\1`/g' <<<"${line}"
					if [[ "${line}" =~ \($ ]]; then
						state="index"
					fi
				fi
				;;
			"index")
				# shellcheck disable=SC2016
				sed -E 's/"([^"]+)"/`\1`/g' <<<"${line}"
				if [[ "${line}" =~ ^\)\; ]]; then
					state="idle"
				fi
				;;
			"table"|"column")
				if [[ "${line}" =~ ^\).*$ ]]; then
					echo -e "\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;"
					state="idle"
				else
					read -r field type <<<"${line}"
					# unwrap from double quotes
					if [[ "${field}" =~ ^\".*\"$ ]]; then
						field="${field:1:-1}"
					fi

					# Add a comma after the last column entry
					if [[ "${state}" == "column" ]]; then
						echo ","
					fi

					if [[ "${field}" =~ PRIMARY|FOREIGN ]]; then
						echo -n "${line%%,}"
					else
						# Use builtin map to find the correct types
						type="$(schema::type_map "${current_table}" "${field}" "${type}")"
						# Map the remaining simple types
						type="$(sed --regexp-extended \
							--expression 's/([^,]+),/\1/g' \
							--expression 's/INTEGER/int(11)/g' \
							--expression 's/SMALLINT/smallint(6)/g' \
							--expression 's/BIGINT/int(10) UNSIGNED/g' \
							--expression 's/TEXT/longtext/g' \
							--expression 's/FLOAT/double/g' \
							--expression 's/BLOB/tinyblob/g' \
							--expression 's/VARCHAR\(([0-9]+)\)/varchar(\1)/g' \
							--expression 's/BOOLEAN/tinyint(1)/g' \
							--expression 's/DATETIME/datetime(6)/g' \
							<<<"${type}")"
						echo -n '  `'"${field}"'` '"${type}"
					fi
					state="column"
				fi
		esac
	done

	echo -e '\nSET FOREIGN_KEY_CHECKS = 1;'
	echo '/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;'
	echo '/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;'
	echo '/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;'
}

if (( $# < 1 )); then
    echo "Usage: $0 <sqlite_schema_file>"
    exit 1
fi

sqlite_schema_file="$1"

if ! [ -r "${sqlite_schema_file}" ]; then
    echo "The file ${sqlite_schema_file} is not readable."
    exit 1
fi

schema::convert < "$1"