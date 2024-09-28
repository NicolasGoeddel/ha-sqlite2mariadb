# shellcheck disable=SC2148,SC2034

## The folder where the SQLite schema and dump should be stored
SQLITE_EXPORT_FOLDER="./sqlite"
## The folder where the converted schema and dump to be imported to MariaDB/MySQL should be stored
MYSQL_IMPORT_FOLDER="./mysql"

#==================#
# HA Configuration #
#==================#
## Can be one of docker, docker-compose, native, custom
HA_INSTALLATION_METHOD=docker-compose

## The path to your docker compose project directory containing the docker-compose.yml file
HA_DOCKER_COMPOSE_PROJECT_PATH="${HOME}/compose/homeassistant"

## The name of the service you gave HomeAssistant inside your docker compose stack
HA_DOCKER_COMPOSE_SERVICE="homeassistant"

## The local path to the SQLite database of Home Assistant
HA_SQLITE_DB_PATH="${HOME}/compose/homeassistant/homeassistant/home-assistant_v2.db"

#==================#
# DB Configuration #
#==================#
## Can be one of docker, docker-compose, native, custom
DB_INSTALLATION_METHOD=docker-compose

## The path to your docker compose project directory containing the docker-compose.yml file
DB_DOCKER_COMPOSE_PROJECT_PATH="${HOME}/compose/homeassistant"

## The name of the service you gave HomeAssistant inside your docker compose stack
DB_DOCKER_COMPOSE_SERVICE="db"

## The path to the binary of your DB instance, it's usually one of /usr/bin/mariadb or /usr/bin/mysql
DB_DOCKER_COMPOSE_BINARY=/usr/bin/mariadb

## The host to connect to (using native DB_INSTALLATION_METHOD)
DB_HOST=core-mariadb
## The user of your HA database
DB_USER=homeassistant

## The password for the user of the database
DB_PASSWORD="$(<"${HOME}/compose/homeassistant/config/db/mariadb_password")"

## The name of the database
DB_NAME="homeassistant"

## DEPRECATED STUFF
PROJECT_DIR=".."

MYSQL_USER="homeassistant"

MYSQL_DB="homeassistant"


