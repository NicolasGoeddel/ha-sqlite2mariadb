# ha-sqlite2mariadb
A migration script for Homeassistant to replace SQLite with MariaDB for better performance.

## Why?
I personally started this project because my SQLite database was just too slow after all that time without purging the data. I mean, why is the default only 10 days? That makes no sense. It had growed to over 4 GiB and showing the dashboards with graphs was terribly slow.

Then I search for other people trying to do the same and found some really good tutorials and step by step guides, but none of them were able to do it fully automatic. So I decided to write this Bash script.

## How?

Here is a step by step explanation of what the script does. Each of the steps can be skipped or executed by choosing between yes and no.

### Step 1 - Stop HA
At first the script checks if HA is currently running and asks you if it is allowed to stop HA.

### Step 2 - Create database dump
If HA was stopped the SQLite database can be dumped. Each table gets its own file containing its data. And there there is the file `schema.sql` containing all the table definitions, primary keys and indices.
Depending on the size of your SQLite database and the machine you are running on this can take a few minutes.

### Step 3 - Start HA again
If HA was running before step 1 you can now start it again if you want to. But be reminded that all data that will be appended to the current SQLite database will get lost unless you start over again and make a new dump.

### Step 4 - Convert schema
In this step the `schmea.sql` will be converted to a proper MySQL/MariaDB schema. For that some column types will be replaced by search and replace and some specific columns will get a completely new type. The necessary information for these irregularities can be found here: https://github.com/home-assistant/core/blob/10a2fd7cb66c2d39c2652c9b85f78e89a0dfc7a9/homeassistant/components/recorder/db_schema.py#L425

### Step 5a - Create schema
In this step all the existing tables in the target database that have the same name as the tables in SQLite will be dropped and recreated, including the primary keys and indices.

### Step 5b - Import data
Now you can begin with importing the data from the dumps created in step 2. This will definitely take much longer than the dump itself. In my case it took around an hour. The biggest table was `states` with nearly 23,000,000 entries.

The import should be quite optimized. It disables the foreign key checks and sets autocommit to false, doing the whole import in one single transaction. If you have good ideas to speed up that step any further, please tell me!

### Step 6 - Set auto increment
In this step a stored procedure is used to add the `AUTO_INCREMENT` modifier to all integer based primary keys. That modifier does not exist in the world of SQLite although it exists implicitely if a column has the type an `INTEGER PRIMARY KEY`. Anyway, while the columns are going to be altered the new auto increment value is also set by selecting the maximum integer in that column, adding 1 to it and set that value.

This process again can take a whole while and you might not see any progress of it in the terminal. Try to be patient. In the background the table needs to be copied again to make that change and therefore it takes that extra bit of a while.

### Step 7 - Review
This is a completely optional step where you can start an interactive MySQL/MariaDB session to have a look at the tables and the data. And from now on you are also ready to change the recorder configuration of your HA setup to use the new database.

## Compatibility
Tested with the following versions of HomeAssistant:
- 2024.6.3

Tested with the following installation methods:
- Docker compose stack with HomeAssistant and MariaDB

## Example output
```
Stop Home Assistant and create database dump? [y/N] y
 * Bring down compose stack.
[+] Running 4/4
 ✔ Container mqtt                       Removed          0.3s
 ✔ Container homeassistant-db-1         Removed          0.5s
 ✔ Container homeassistant              Removed          5.4s
 ✔ Network homeassistant_homeassistant  Removed          0.2s
 * Create SQLite database dump.
   - Dumping schema... done.
   - Dumping table 'event_data'... done (1260 lines written).
   - Dumping table 'state_attributes'... done (4312174 lines written).
   - Dumping table 'statistics_meta'... done (48 lines written).
   - Dumping table 'recorder_runs'... done (84 lines written).
   - Dumping table 'schema_changes'... done (16 lines written).
   - Dumping table 'statistics_runs'... done (152229 lines written).
   - Dumping table 'events'... done (185196 lines written).
   - Dumping table 'statistics'... done (400225 lines written).
   - Dumping table 'statistics_short_term'... done (4591028 lines written).
   - Dumping table 'states'... done (22659923 lines written).
   - Dumping table 'event_types'... done (35 lines written).
   - Dumping table 'states_meta'... done (173 lines written).
   - Dumping table 'migration_changes'... done (6 lines written).
 * Dir listing of the dump:
     -rw-r--r-- 1 root    root    5,0G 19. Jun 19:20 ../homeassistant/home-assistant_v2.db
     -rw-r--r-- 1 user user  32K 19. Jun 19:23 ../homeassistant/home-assistant_v2.db-shm
     -rw-r--r-- 1 user user    0 19. Jun 19:20 ../homeassistant/home-assistant_v2.db-wal
     -rw-r--r-- 1 user user 209K 19. Jun 19:20 ./sqlite/data_event_data.sql
     -rw-r--r-- 1 user user  27M 19. Jun 19:21 ./sqlite/data_events.sql
     -rw-r--r-- 1 user user 2,0K 19. Jun 19:23 ./sqlite/data_event_types.sql
     -rw-r--r-- 1 user user  361 19. Jun 19:23 ./sqlite/data_migration_changes.sql
     -rw-r--r-- 1 user user  11K 19. Jun 19:21 ./sqlite/data_recorder_runs.sql
     -rw-r--r-- 1 user user 1,1K 19. Jun 19:21 ./sqlite/data_schema_changes.sql
     -rw-r--r-- 1 user user 1,1G 19. Jun 19:21 ./sqlite/data_state_attributes.sql
     -rw-r--r-- 1 user user  12K 19. Jun 19:23 ./sqlite/data_states_meta.sql
     -rw-r--r-- 1 user user 4,0G 19. Jun 19:23 ./sqlite/data_states.sql
     -rw-r--r-- 1 user user 4,5K 19. Jun 19:21 ./sqlite/data_statistics_meta.sql
     -rw-r--r-- 1 user user  11M 19. Jun 19:21 ./sqlite/data_statistics_runs.sql
     -rw-r--r-- 1 user user 751M 19. Jun 19:21 ./sqlite/data_statistics_short_term.sql
     -rw-r--r-- 1 user user  62M 19. Jun 19:21 ./sqlite/data_statistics.sql
     -rw-r--r-- 1 user user 4,7K 19. Jun 19:20 ./sqlite/schema.sql
 * Start Home Assistant again.
[+] Running 4/4
 ✔ Network homeassistant_homeassistant  Created          0.0s
 ✔ Container mqtt                       Started          0.6s
 ✔ Container homeassistant              Started          0.7s
 ✔ Container homeassistant-db-1         Started          0.4s
Convert SQLite schema to MySQL? [y/N] y
 * Convert schema... done.
 * Symbolic link data    - mysql/data_event_data.sql -> ../sqlite/data_event_data.sql
   - mysql/data_events.sql -> ../sqlite/data_events.sql
   - mysql/data_event_types.sql -> ../sqlite/data_event_types.sql
   - mysql/data_migration_changes.sql -> ../sqlite/data_migration_changes.sql
   - mysql/data_recorder_runs.sql -> ../sqlite/data_recorder_runs.sql
   - mysql/data_schema_changes.sql -> ../sqlite/data_schema_changes.sql
   - mysql/data_state_attributes.sql -> ../sqlite/data_state_attributes.sql
   - mysql/data_states_meta.sql -> ../sqlite/data_states_meta.sql
   - mysql/data_states.sql -> ../sqlite/data_states.sql
   - mysql/data_statistics_meta.sql -> ../sqlite/data_statistics_meta.sql
   - mysql/data_statistics_runs.sql -> ../sqlite/data_statistics_runs.sql
   - mysql/data_statistics_short_term.sql -> ../sqlite/data_statistics_short_term.sql
   - mysql/data_statistics.sql -> ../sqlite/data_statistics.sql
Delete existing data and import schema? [y/N] y
 * Insert data? [y/N] y
   - Importing data_event_data.sql... done.
   - Importing data_events.sql... done.
   - Importing data_event_types.sql... done.
   - Importing data_migration_changes.sql... done.
   - Importing data_recorder_runs.sql... done.
   - Importing data_schema_changes.sql... done.
   - Importing data_state_attributes.sql... done.
   - Importing data_states_meta.sql... done.
   - Importing data_states.sql... done.
   - Importing data_statistics_meta.sql... done.
   - Importing data_statistics_runs.sql... done.
   - Importing data_statistics_short_term.sql... done.
   - Importing data_statistics.sql... done.
Update AUTO_INCREMENT values? [y/N] y
state_attributes
Add AUTO_INCREMENT and set AUTO_INCREMENT to 4328320
statistics
Add AUTO_INCREMENT and set AUTO_INCREMENT to 400224
statistics_runs
Add AUTO_INCREMENT and set AUTO_INCREMENT to 168170
event_data
Add AUTO_INCREMENT and set AUTO_INCREMENT to 2157
states
Add AUTO_INCREMENT and set AUTO_INCREMENT to 23645748
recorder_runs
Add AUTO_INCREMENT and set AUTO_INCREMENT to 128
states_meta
Add AUTO_INCREMENT and set AUTO_INCREMENT to 172
events
Add AUTO_INCREMENT and set AUTO_INCREMENT to 191280
statistics_meta
Add AUTO_INCREMENT and set AUTO_INCREMENT to 47
schema_changes
Add AUTO_INCREMENT and set AUTO_INCREMENT to 15
event_types
Add AUTO_INCREMENT and set AUTO_INCREMENT to 34
statistics_short_term
Add AUTO_INCREMENT and set AUTO_INCREMENT to 4799290
Login to MySQL? [y/N]
```

## Standalone scripts

The script `sqlite2mariadb.sh` can be used to convert a SQLite database schema to a MariaDB/MySQL compatiable schema. The first and only parameter must be the schema file, then the converted schema will be writte on standard out.

Make sure to only feed a proper schema to the converter script. This can be done like this:
```bash
sqlite3 -readonly sqlite.db ".schema --indent" > sqlite_db_schema.sql
sqlite2mariadb.sh sqlite_db_schema.sql > mariadb_db_schema.sql
```