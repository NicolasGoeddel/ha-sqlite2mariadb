# ha-sqlite2mariadb
A migration script for Homeassistant to replace SQLite with MariaDB for better performance.

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