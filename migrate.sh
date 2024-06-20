#!/bin/bash

set -eu

# shellcheck source=./migration.conf.sh
source ./migration.conf.sh

# Set to true if you want to answer each question with 'yes'.
alwaysYes=false

# Automatically set to true if the database schema was overriden
db_fresh_schema=false

case "${HA_INSTALLATION_METHOD}" in
	docker-compose)
		;;
	*)
		echo "Unfortunately the installation method ${HA_INSTALLATION_METHOD} is not yet supported by this migration script." >&2
		exit 1
		;;
esac

function ha::config_check() {
	local error=false
	case "${HA_INSTALLATION_METHOD}" in
		docker-compose)
			if ! [[ -d "${HA_DOCKER_COMPOSE_PROJECT_PATH}" ]]; then
				echo "Directory does not exist: HA_DOCKER_COMPOSE_PROJECT_PATH='${HA_DOCKER_COMPOSE_PROJECT_PATH}'"
				error=true
			fi
			if [[ -z "${HA_DOCKER_COMPOSE_SERVICE}" ]]; then
				echo "Service name empty: HA_DOCKER_COMPOSE_SERVICE"
				error=true
			fi
			if ! [[ -r "${HA_SQLITE_DB_PATH}" ]]; then
				echo "SQLite database seems not to be readable: HA_SQLITE_DB_PATH='${HA_SQLITE_DB_PATH}'"
				error=true
			fi
			;;
		*)
			echo "Unknown installation method. Can only be one of: docker, docker-compose, native, custom"
			error=true
			;;
	esac
	${error} && return 1
	return 0
}

function ha::running() {
	case "${HA_INSTALLATION_METHOD}" in
		docker-compose)
			local id;
			id="$(docker compose --project-directory "${HA_DOCKER_COMPOSE_PROJECT_PATH}" \
				ps --quiet \
				--status running \
				"${HA_DOCKER_COMPOSE_SERVICE}"
			)"
			[[ -n "${id}" ]] && return 0
			return 1
	esac
}

function ha::stop() {
	case "${HA_INSTALLATION_METHOD}" in
		docker-compose)
			docker compose --project-directory "${HA_DOCKER_COMPOSE_PROJECT_PATH}" down "${HA_DOCKER_COMPOSE_SERVICE}"
			;;
	esac
}

function ha::start() {
	case "${HA_INSTALLATION_METHOD}" in
		docker-compose)
			docker compose --project-directory "${HA_DOCKER_COMPOSE_PROJECT_PATH}" up -d "${HA_DOCKER_COMPOSE_SERVICE}"
			;;
	esac
}

function db::config_check() {
	local error=false
	case "${DB_INSTALLATION_METHOD}" in
		docker-compose)
			if ! [[ -d "${DB_DOCKER_COMPOSE_PROJECT_PATH}" ]]; then
				echo "Directory does not exist: DB_DOCKER_COMPOSE_PROJECT_PATH='${DB_DOCKER_COMPOSE_PROJECT_PATH}'"
				error=true
			fi
			if [[ -z "${DB_DOCKER_COMPOSE_SERVICE}" ]]; then
				echo "Service name empty: DB_DOCKER_COMPOSE_SERVICE"
				error=true
			fi
			if [[ -z "${DB_DOCKER_COMPOSE_BINARY}" ]]; then
				echo "DB binary path is empty: DB_DOCKER_COMPOSE_BINARY"
				error=true
			fi
			;;
		*)
			echo "Unknown installation method. Can only be one of: docker, docker-compose, native, custom"
			error=true
			;;
	esac
	${error} && return 1
	return 0
}

function db::execute() {
	case "${DB_INSTALLATION_METHOD}" in
		docker-compose)
			docker compose \
				--project-directory "${DB_DOCKER_COMPOSE_PROJECT_PATH}" \
				exec --no-TTY "${DB_DOCKER_COMPOSE_SERVICE}" \
				"${DB_DOCKER_COMPOSE_BINARY}" \
				--default-character-set utf8mb4 \
				--user="${DB_USER}" --password="${DB_PASSWORD}" "${DB_NAME}" \
				< "${MYSQL_IMPORT_FOLDER}/schema.sql"
			;;
		*)
			;;
	esac
}

# shellcheck disable=SC2120
function yesNo() {
	# Der erste Parameter bestimmt die Default-Antwort. Der Default vom Default ist 'n'.
	if ${alwaysYes:-false}; then
		echo "Yes"
		return 0
	fi
	local answer
	local default
	read -r answer
	default="${1:-n}"
	answer="${answer:-${default}}"
	answer="${answer,,}"
	if [[ "${answer}" =~ ^(y|yes|j|ja)$ ]]; then
		return 0
	fi
	return 1
}

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

ha::config_check
db::config_check

# Remember if HA was running
ha_was_running=false
# Assume HA is stopped per default
ha_stopped=true

if ha::running; then
	ha_was_running=true
	ha_stopped=false
fi

if ${ha_was_running}; then
	echo -n "Home Assistant must be stopped before the database dump can be created. Proceed? [y/N] "
	if yesNo; then
		ha::stop
		if ha::running; then
			echo "For some reason Home Assistant could not be stopped. Quit." >&2
			exit 1
		fi
		ha_was_running=true
		ha_stopped=true
	fi
fi

if ${ha_stopped}; then
	echo -n "Do you want to create the database dump now? [y/N] "
	if yesNo; then
		if ! [ -r "${HA_SQLITE_DB_PATH}" ]; then
			echo "Database does not exist or is not readable: ${HA_SQLITE_DB_PATH}" >&2
			exit 1
		fi

		mkdir -p "${SQLITE_EXPORT_FOLDER}"
		rm -f "${SQLITE_EXPORT_FOLDER}"/.done

		echo " * Create SQLite database dump."
		{
			echo -n "   - Dumping schema... "
			sqlite3 -readonly "${HA_SQLITE_DB_PATH}" ".schema --indent" > "${SQLITE_EXPORT_FOLDER}/schema.sql"
			echo "done."
		}

		mapfile -t sqlite_tables < <(sqlite3 "${HA_SQLITE_DB_PATH}" "SELECT name FROM sqlite_master WHERE type = 'table' AND name != 'sqlite_stat1';")
		{
			for table in "${sqlite_tables[@]}"; do
				echo -n "   - Dumping table '${table}'... "
				{
					echo "ALTER TABLE \`${table}\` DISABLE KEYS;"
					sqlite3 -readonly "${HA_SQLITE_DB_PATH}" <<-EOF
						.headers off
						.mode insert ${table}
						SELECT * FROM ${table};
EOF
					echo "ALTER TABLE \`${table}\` ENABLE KEYS;"
				} > "${SQLITE_EXPORT_FOLDER}/data_${table}.sql"
				lines="$(wc -l < "${SQLITE_EXPORT_FOLDER}/data_${table}.sql")"
				echo "done (${lines} lines written)."
			done
		}

		echo " * Dir listing of the dump:"
		# shellcheck disable=SC2012
		ls -lhd "${HA_SQLITE_DB_PATH}"* "${SQLITE_EXPORT_FOLDER}"/{schema,data_*}.sql | sed 's/^/     /g'

		touch "${SQLITE_EXPORT_FOLDER}"/.done
	fi

	if ${ha_was_running}; then
		echo -n "Do you want to start Home Assistant again? [y/N] "
		if yesNo; then
			if ! ha::start; then
				echo "Was not able to start Home Assistant again." >&2
				echo -n "Proceed anyway? [y/N] "
				if ! yesNo; then
					exit 1
				fi
			fi
		fi
	fi
fi

if [[ -f "${SQLITE_EXPORT_FOLDER}"/.done ]]; then
	echo -n "Convert SQLite schema to MySQL? [y/N] "
	if yesNo; then
		echo -n " * Remove old dumps if existent... "
		mkdir -p "${MYSQL_IMPORT_FOLDER}"
		rm -f "${MYSQL_IMPORT_FOLDER}"/.done
		rm -rf "${MYSQL_IMPORT_FOLDER}"/data_*.sql
		echo "done."

		echo -n " * Convert schema... "
		schema::convert < "${SQLITE_EXPORT_FOLDER}/schema.sql" > "${MYSQL_IMPORT_FOLDER}/schema.sql"
		echo "done."
		echo " * Symbolic link data"
		for file in "${SQLITE_EXPORT_FOLDER}/data_"*.sql; do
			source="$(realpath "${file}")"
			destination="${MYSQL_IMPORT_FOLDER}/$(basename "${source}")"
			rel_source="$(realpath --relative-to "${MYSQL_IMPORT_FOLDER}" "${source}")"
			rel_destination="$(realpath --relative-to "$(pwd)" "${destination}")"
			if ln -sf "${rel_source}" "${destination}"; then
				echo "   - ${rel_destination} -> ${rel_source}"
			fi
		done
		touch "${MYSQL_IMPORT_FOLDER}"/.done
	fi
fi

if [[ -f "${MYSQL_IMPORT_FOLDER}"/.done ]]; then
	echo -n "Delete existing data and import schema? [y/N] "
	db_fresh_schema=false
	if yesNo; then
		if db::execute < "${MYSQL_IMPORT_FOLDER}/schema.sql"; then
			db_fresh_schema=true
		fi
	fi
	if ${db_fresh_schema}; then
		echo -n " * Insert previously converted data? [y/N] "
		if yesNo; then
			exec 3>&1
			{
				echo "SET FOREIGN_KEY_CHECKS = 0;"
				echo "SET AUTOCOMMIT = 0;"
				echo "START TRANSACTION;"
				for file in "${SQLITE_EXPORT_FOLDER}/data_"*.sql; do
					echo -n "   - Importing $(basename "${file}")... " >&3
					cat "${file}"
					echo "done." >&3
				done
				echo "COMMIT;"
				echo "SET AUTOCOMMIT = 0;"
				echo "SET FOREIGN_KEY_CHECKS = 0;"
			} | db::execute
		fi
	fi
fi

echo -n "Set and update AUTO_INCREMENT values? [y/N] "
if yesNo; then
	db::execute <<<"
DROP PROCEDURE IF EXISTS adjust_auto_increment;
DELIMITER //
CREATE PROCEDURE adjust_auto_increment()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_table_name VARCHAR(255);
    DECLARE v_column_name VARCHAR(255);
    DECLARE v_column_type VARCHAR(255);
    DECLARE v_data_type VARCHAR(255);
    DECLARE v_extra VARCHAR(255);
    DECLARE max_id BIGINT;

    -- Cursor to iterate over all primary key columns
    DECLARE cur CURSOR FOR
        SELECT table_name, column_name, column_type, extra, data_type
        FROM information_schema.columns
        WHERE column_key = 'PRI';

    -- Handle the end of the cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cur;

    -- Loop over all primary key columns
    read_loop: LOOP
        FETCH cur INTO v_table_name, v_column_name, v_column_type, v_extra, v_data_type;

        -- Stop when there are no more columns
        IF done THEN
            LEAVE read_loop;
        END IF;

        if (v_data_type = 'int') THEN
            -- Find maximum of the column
            EXECUTE IMMEDIATE CONCAT('SELECT MAX(', v_column_name, ') INTO @max_id FROM ', v_table_name);

            -- If there was no entry, set the maximum to 0
            IF (@max_id IS NULL) THEN
                SET @max_id = 0;
            END IF;

            -- Add AUTO_INCREMENT and set its value to the max value + 1
            IF (v_extra = 'auto_increment') THEN
                EXECUTE IMMEDIATE CONCAT('SELECT \'Set AUTO_INCREMENT to ', @max_id + 1, '\' AS ', v_table_name);
                EXECUTE IMMEDIATE CONCAT('ALTER TABLE ', v_table_name, ' AUTO_INCREMENT = ', @max_id + 1);
            ELSE
                EXECUTE IMMEDIATE CONCAT('SELECT \'Add AUTO_INCREMENT and set AUTO_INCREMENT to ', @max_id + 1, '\' AS ', v_table_name);
                EXECUTE IMMEDIATE CONCAT('ALTER TABLE ', v_table_name, ' MODIFY ', v_column_name, ' ', v_column_type, ' AUTO_INCREMENT, AUTO_INCREMENT = ', @max_id + 1);
            END IF;
        END IF;
    END LOOP;

    -- Cursor schließen
    CLOSE cur;
END //

DELIMITER ;

-- Prozedur ausführen
CALL adjust_auto_increment();
"
fi

echo -n "Login to MySQL? [y/N] "
if yesNo; then
	docker compose \
		--project-directory "${PROJECT_DIR}" \
		exec db \
		/usr/bin/mariadb --default-character-set utf8mb4 --user="${MYSQL_USER}" --password="${MYSQL_PASSWORD}" "${MYSQL_DB}"
fi