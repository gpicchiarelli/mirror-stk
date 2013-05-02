/*
    SQLToolKit/Unit
	Copyright Federico Razzoli  2012, 2013
	
	This file is part of SQLToolKit/Unit.
	
    SQLToolKit/Unit is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, version 3 of the License.
	
    SQLToolKit/Unit is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.
	
    You should have received a copy of the GNU Affero General Public License
    along with SQLToolKit/Unit.  If not, see <http://www.gnu.org/licenses/>.
*/


/*
	test_checkup is a Test Case for STK/Unit.
	Checks for configuration problems, and issues which can come up in a server 
	installation after some usage.
	Asserts are generally based on advices found in MariaDB KnowledgeBase,
	in Percona's blogs or in MySQL documentation. Links to those articles are
	provided in the source code.
	However, keep in mind that the Real World complexity can not be summarized
	in the manuals. So, even if test_checkup triggers many fail on your server,
	your configuration could be perfect for your database and your worklog.
	test_checkup aims to:
	* give some hints to users who don't know much about configuration;
	* help find forgotten objects in your databases;
	* serve as example of uncommon Test Case.
*/


DELIMITER ||

##begin


-- make the server as strict as possible
SET @__stk_u_old_SQL_MODE = @@session.SQL_MODE;
SET @@session.SQL_MODE = 'ERROR_FOR_DIVISION_BY_ZERO,NO_ZERO_DATE,NO_ZERO_IN_DATE,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION,ONLY_FULL_GROUP_BY,STRICT_ALL_TABLES,STRICT_TRANS_TABLES';
SET @__stk_u_old_sql_warnings = @@session.sql_warnings;
SET @@session.sql_warnings = TRUE;
SET @__stk_u_old_sql_notes = @@session.sql_notes;
SET @@session.sql_notes = TRUE;
SET @__stk_u_old_unique_checks = @@session.unique_checks;
SET @@session.unique_checks = TRUE;
SET @__stk_u_old_foreign_key_checks = @@session.foreign_key_checks;
SET @@session.foreign_key_checks = TRUE;
-- MariaDB and MySQL > 5.1 support innodb_strict_mode
SET /*!50200 @__stk_u_old_innodb_strict_mode = @@session.innodb_strict_mode, */ @__stk_u_tmp = NULL;
SET /*!50200 @@session.innodb_strict_mode = TRUE, */ @__stk_u_tmp = NULL;
SET /*M! @__stk_u_old_innodb_strict_mode = @@session.innodb_strict_mode, */ @__stk_u_tmp = NULL;
SET /*M! @@session.innodb_strict_mode = TRUE, */ @__stk_u_tmp = NULL;


-- create & select db
DROP DATABASE IF EXISTS `test_checkup`;
CREATE DATABASE `test_checkup`;
USE `test_checkup`;


/*
 *	Check Server Variables
 */


-- Test that important SQL_MODE flags are set globally.
-- If they are not, some errors happen silently,
-- or some commands do something different from what you think
-- (e.g. you could create a MyISAM table instead of InnoDB).
CREATE PROCEDURE test_sql_mode()
	LANGUAGE SQL
	COMMENT 'Test that important SQL_MODE flags are set'
BEGIN
	-- http://falseisnotnull.wordpress.com/2013/03/10/setting-a-strict-sql_mode/#ERROR_FOR_DIVISION_BY_ZERO
	CALL `stk_unit`.assert_like(@@global.sql_mode, 'ERROR_FOR_DIVISION_BY_ZERO',
		'Warning: SQL_MODE flag ERROR_FOR_DIVISION_BY_ZERO unset');
	
	-- http://falseisnotnull.wordpress.com/2013/03/10/setting-a-strict-sql_mode/#NO_AUTO_CREATE_USER
	CALL `stk_unit`.assert_like(@@global.sql_mode, 'NO_AUTO_CREATE_USER',
		'Warning: SQL_MODE flag NO_AUTO_CREATE_USER unset');
	
	-- http://falseisnotnull.wordpress.com/2013/03/10/setting-a-strict-sql_mode/#NO_AUTO_VALUE_ON_ZERO
	CALL `stk_unit`.assert_like(@@global.sql_mode, 'NO_AUTO_VALUE_ON_ZERO',
		'Warning: SQL_MODE flag NO_AUTO_VALUE_ON_ZERO unset');
	
	-- http://falseisnotnull.wordpress.com/2013/03/10/setting-a-strict-sql_mode/#NO_ENGINE_SUBSTITUTION
	CALL `stk_unit`.assert_like(@@global.sql_mode, 'NO_ENGINE_SUBSTITUTION',
		'Warning: SQL_MODE flag NO_ENGINE_SUBSTITUTION unset');
	
	-- http://falseisnotnull.wordpress.com/2013/03/10/setting-a-strict-sql_mode/#NO_ZERO_DATE
	CALL `stk_unit`.assert_like(@@global.sql_mode, 'NO_ZERO_DATE',
		'Warning: SQL_MODE flag NO_ZERO_DATE unset');
	
	-- http://falseisnotnull.wordpress.com/2013/03/10/setting-a-strict-sql_mode/#NO_ZERO_IN_DATE
	CALL `stk_unit`.assert_like(@@global.sql_mode, 'NO_ZERO_IN_DATE',
		'Warning: SQL_MODE flag NO_ZERO_IN_DATE unset');
	
	-- http://falseisnotnull.wordpress.com/2013/03/10/setting-a-strict-sql_mode/#ONLY_FULL_GROUP_BY
	CALL `stk_unit`.assert_like(@@global.sql_mode, 'ONLY_FULL_GROUP_BY',
		'Warning: SQL_MODE flag ONLY_FULL_GROUP_BY unset');
	
	-- http://falseisnotnull.wordpress.com/2013/03/10/setting-a-strict-sql_mode/#STRICT_ALL_TABLES
	CALL `stk_unit`.assert_like(@@global.sql_mode, 'STRICT_ALL_TABLES',
		'Warning: SQL_MODE flag STRICT_ALL_TABLES unset');
	
	-- http://falseisnotnull.wordpress.com/2013/03/10/setting-a-strict-sql_mode/#STRICT_TRANS_TABLES
	CALL `stk_unit`.assert_like(@@global.sql_mode, 'STRICT_TRANS_TABLES',
		'Warning: SQL_MODE flag STRICT_TRANS_TABLES unset');
END;


-- strictness variables, except for sql_mode
CREATE PROCEDURE test_strictness()
	LANGUAGE SQL
	COMMENT 'Test strictness variables, except for sql_mode'
BEGIN
	-- foreign_key_checks must be on, if there are Foreign Keys
	CALL `stk_unit`.assert_false(
			@@global.foreign_key_checks = 0
			AND EXISTS (
					SELECT 1
						FROM `information_schema`.`TABLE_CONSTRAINTS`
						WHERE `CONSTRAINT_TYPE` LIKE 'FOREIGN KEY'
				),
			'Warning: Foreign Keys were found but foreign_key_checks is OFF'
		);
	
	-- unique_checks
	CALL `stk_unit`.assert_true(
			@@global.unique_checks = 1,
			'Warning: unique_checks should be ON'
		);
	
	-- sql_warnings
	CALL `stk_unit`.assert_true(
			@@global.sql_warnings = 1,
			'Warning: sql_warnings should be ON'
		);
	
	-- innodb_strict_mode
	CALL `stk_unit`.assert_true(
			@@global.innodb_strict_mode = 1,
			'Warning: innodb_strict_mode should be ON'
		);
END;


-- autocommit can cause "surprises", so it's better to disable it globally
CREATE PROCEDURE test_autocommit()
	LANGUAGE SQL
	COMMENT 'Test that autocommit is off'
BEGIN
	-- http://dev.mysql.com/doc/refman/5.5/en/server-system-variables.html#sysvar_autocommit
	CALL `stk_unit`.assert_false(
			@@global.autocommit,
			'@@global.autocommit is TRUE. Tip: disable autocommit globally'
		);
END;


-- MyISAM is used for system tables, and Aria is used on MariaDB for temptables.
-- so, autorecovery should always be enabled.
-- however, checking the exact option would be too invasive
CREATE PROCEDURE test_myisam_recover()
	LANGUAGE SQL
	COMMENT 'Test that MyISAM recover is used'
BEGIN
	-- MyISAM recovery
	CALL `stk_unit`.assert_true(@@global.myisam_recover_options NOT LIKE 'OFF' AND @@global.myisam_recover_options <> '',
		'Disabling MyISAM recover is unsafe');
	
	-- for MariaDB, check Aria recovery
	IF VERSION() LIKE '%mariadb%' THEN
		CALL `stk_unit`.assert_true(@@global.aria_recover NOT LIKE 'OFF' AND @@global.aria_recover <> '',
			'Disabling Aria recover is unsafe');
	END IF;
END;


-- https://kb.askmonty.org/en/optimizing-key_buffer_size/
CREATE PROCEDURE test_key_buffer_size()
	LANGUAGE SQL
	COMMENT 'Test var key_buffer_size'
BEGIN
	-- status value
	DECLARE `key_reads` BIGINT UNSIGNED DEFAULT 
		(SELECT `VARIABLE_VALUE` FROM `information_schema`.`GLOBAL_STATUS` WHERE `VARIABLE_NAME` LIKE 'key_reads');
	-- status value
	DECLARE `key_read_requests` BIGINT UNSIGNED DEFAULT 
		(SELECT `VARIABLE_VALUE` FROM `information_schema`.`GLOBAL_STATUS` WHERE `VARIABLE_NAME` LIKE 'key_read_requests');
	
	CALL `stk_unit`.assert_true(
		(key_reads / key_read_requests) < (1 / 100),
		CONCAT(
				'key_reads = ', key_reads, '; key_read_requests = ', key_read_requests, '. ',
				'Tip: ratio should be < 1/100'
			)
		);
END;


-- https://kb.askmonty.org/en/optimizing-table_open_cache/
CREATE PROCEDURE test_table_open_cache()
	LANGUAGE SQL
	COMMENT 'Test var table_open_cache'
BEGIN
	DECLARE first_read   INTEGER UNSIGNED;
	DECLARE second_read  INTEGER UNSIGNED;
	
	-- for 5.0: table_open_cache was called table_cache
	
	-- read twice num of opened tables, with 1 second interval
	SET first_read   =
		(SELECT `VARIABLE_VALUE` FROM `information_schema`.`GLOBAL_STATUS` WHERE `VARIABLE_NAME` LIKE 'opened_tables');
	DO SLEEP(1);
	SET second_read  =
		(SELECT `VARIABLE_VALUE` FROM `information_schema`.`GLOBAL_STATUS` WHERE `VARIABLE_NAME` LIKE 'opened_tables');
	
	-- compare the reads: did opened_tables grow too much?
	IF (first_read * 1.33) < second_read THEN
		CALL `stk_unit`.assert_true(FALSE,
			'opened_tables increased too much in 1 second. Tip: increase table_open_cache');
	ELSEIF second_read < (@@global.table_open_cache * 0.7) THEN
		-- didn't grow too much. is it too low, then?
		CALL `stk_unit`.assert_true(FALSE,
			CONCAT(
				'opened_tables = ', second_read, '; ',
				'table_open_cache = ', @@global.table_open_cache, '. ',
				'Tip: maybe table_open_cache is too high')
			);
	ELSE
		-- seems to be ok; trigger a Pass
		-- didn't grow too much. is it too low, then?
		CALL `stk_unit`.assert_true(TRUE, 'opened_tables seems to be ok');
	END IF;
END;


-- https://kb.askmonty.org/en/handling-too-many-connections/
CREATE PROCEDURE test_max_connections()
	LANGUAGE SQL
	COMMENT 'Test var max_connections'
BEGIN
	-- max_used_connections is the past peak of opened thds
	DECLARE `max_used_connections` BIGINT UNSIGNED DEFAULT 
		(SELECT `VARIABLE_VALUE` FROM `information_schema`.`GLOBAL_STATUS` WHERE `VARIABLE_NAME` LIKE 'max_used_connections');
	
	-- compare max_connections to max_used_connections
	
	-- max_connections too high?
	CALL `stk_unit`.assert_false(@@global.max_connections > ROUND(max_used_connections * 1.5),
		CONCAT(
				'max_connections = ', @@global.max_connections, '; max_used_connections = ', max_used_connections, '. ',
				'Tip: maybe max_connections is too high'
			)
		);
	
	-- max_connections too low?
	CALL `stk_unit`.assert_false(@@global.max_connections < ROUND(max_used_connections * 0.6),
		CONCAT(
				'max_connections = ', @@global.max_connections, '; max_used_connections = ', max_used_connections, '. ',
				'Tip: maybe max_connections is too low'
			)
		);
END;


-- test things that are not safe with Statement-Based Replication
-- SBR = (binlog_format = 'statement')
CREATE PROCEDURE test_rbr()
	LANGUAGE SQL
	COMMENT 'Test things that are not safe with SBR'
BEGIN
	-- if a variable does not exist in current version,
	-- just skip the relative assertion
	DECLARE CONTINUE HANDLER
		FOR 1193
		DO NULL;
	
	IF @@global.binlog_format LIKE 'STATEMENT' THEN
		-- innodb_autoinc_lock_mode = 2 unsafe
		-- http://dev.mysql.com/doc/refman/5.1/en/innodb-auto-increment-handling.html
		-- https://kb.askmonty.org/en/auto_increment-handling-in-xtradbinnodb/
		CALL `stk_unit`.assert_not_equals(@@global.innodb_autoinc_lock_mode, 2,
			'@@global.innodb_autoinc_lock_mode = 2 unsafe with SBR');
	END IF;
END;


-- test things that are not safe with binary log
-- binlog = (log_bin NOT LIKE 'OFF')
CREATE PROCEDURE test_binlog()
	LANGUAGE SQL
	COMMENT 'Test things that are not safe with binary log'
BEGIN
	IF @@global.log_bin NOT LIKE 'OFF' THEN
		-- innodb_support_xa is essential for binary log
		-- http://dev.mysql.com/doc/refman/5.1/en/innodb-parameters.html#sysvar_innodb_support_xa
		CALL `stk_unit`.assert_true(@@global.innodb_support_xa IS TRUE,
			'XA is essential for binary log reliability');
	END IF;
END;


-- Test things related to temptables
CREATE PROCEDURE test_temptables()
	LANGUAGE SQL
	COMMENT 'Test things that are not safe with binary log'
BEGIN
	DECLARE `created_tmp_tables` BIGINT UNSIGNED DEFAULT 
		(SELECT `VARIABLE_VALUE` FROM `information_schema`.`GLOBAL_STATUS` WHERE `VARIABLE_NAME` LIKE 'created_tmp_tables');
	DECLARE `created_tmp_disk_tables` BIGINT UNSIGNED DEFAULT 
		(SELECT `VARIABLE_VALUE` FROM `information_schema`.`GLOBAL_STATUS` WHERE `VARIABLE_NAME` LIKE 'Created_tmp_disk_tables');
	
	-- check how many temptables had to be written on disk
	CALL `stk_unit`.assert_true(
			(created_tmp_tables * 0.5) > created_tmp_disk_tables,
			CONCAT(
					'created_tmp_tables = ', created_tmp_tables, '; created_tmp_disk_tables = ', created_tmp_disk_tables, '. ',
					'Tip: increment tmp_table_size or max_heap_table_size'
				)
		);
	
	-- on MariaDB, Aria should be used for on-disk temptables
	IF VERSION() LIKE '%mariadb%' THEN
		CALL `stk_unit`.assert_true(@@global.aria_used_for_temp_tables NOT LIKE 'ON',
			'aria_used_for_temp_tables is OFF. Tip: use Aria for on-disk temptables');
	END IF;
END;


-- Test Aria-related variables that are not tested elsewhere
CREATE PROCEDURE test_aria()
	LANGUAGE SQL
	COMMENT 'Test misc Aria vars'
BEGIN
	IF VERSION() LIKE '%mariadb%' THEN
		-- aria_group_commit = 'soft' is dangerous
		-- https://kb.askmonty.org/en/aria-storage-engine/
		CALL `stk_unit`.assert_true(@@global.aria_group_commit NOT LIKE 'soft',
			'Warning: aria_group_commit = "soft" is dangerous');
	END IF;
END;


/*
 *	Check information_schema
 */

-- Test if there are unused Stored Engines that
-- are not installed by default
CREATE PROCEDURE test_unused_se()
	LANGUAGE SQL
	COMMENT 'Unused non-default Storage Engines'
BEGIN
	-- end for `crs_engines`
	DECLARE `eof`  BOOLEAN  DEFAULT FALSE;
	-- current unused engine
	DECLARE `se`   TEXT     DEFAULT NULL;
	
	-- cursor which finds unused engines
	DECLARE `crs_engines` CURSOR FOR
		SELECT `ENGINE`
			FROM `information_schema`.`ENGINES`
			WHERE
				-- exclude used engines
				`ENGINE` NOT IN (SELECT DISTINCT `ENGINE` FROM `information_schema`.`TABLES` WHERE `ENGINE` IS NOT NULL)
				-- exclude default engines from the list
				AND `ENGINE` NOT IN ('InnoDB', 'Aria', 'MyISAM', 'MRG_MYISAM', 'MEMORY', 'INFORMATION_SCHEMA', 'PERFORMANCE_SCHEMA');
	
	DECLARE CONTINUE HANDLER
		FOR NOT FOUND
		SET `eof` = TRUE;
	
	-- for each unused non-default SE (row returned by `crs_engines`)
	-- a fail is triggered with the SE name
	OPEN `crs_engines`;
	`lp_engines`:
	LOOP
		FETCH NEXT FROM `crs_engines`
			INTO `se`;
		
		IF `eof` IS TRUE THEN
			LEAVE `lp_engines`;
		END IF;
		
		CALL `stk_unit`.assert_true(
				FALSE,
				CONCAT('Unused non-default Stored Engine: ', `se`)
			);
	END LOOP;
	CLOSE `crs_engines`;
END;


-- Test that default SE is the most used
CREATE PROCEDURE test_default_storage_engine()
	LANGUAGE SQL
	COMMENT 'Test that default SE is the most used'
BEGIN
	-- most used se
	DECLARE `se` TEXT DEFAULT
		(SELECT `ENGINE`
			FROM `information_schema`.`TABLES`
			WHERE `ENGINE` IS NOT NULL
			GROUP BY `ENGINE`
			ORDER BY COUNT(*) DESC
			LIMIT 1);
	
	CALL `stk_unit`.assert_true(
			(`se` = @@global.storage_engine),
			CONCAT(
					'Default Storage Engine is ', @@global.storage_engine, ', but the most used is ', `se` 
				)
		);
END;


-- Test if there are empty databases
CREATE PROCEDURE test_empty_databases()
	LANGUAGE SQL
	COMMENT 'Test if there are empty schemas'
BEGIN
	-- end for `crs_sch`
	DECLARE `eof`       BOOLEAN  DEFAULT FALSE;
	-- empty db
	DECLARE `sch_name`  TEXT     DEFAULT NULL;
	
	-- cursor which finds unused engines
	DECLARE `crs_sch` CURSOR FOR
		SELECT `SCHEMA_NAME`
			FROM `information_schema`.`SCHEMATA`
			WHERE
				`SCHEMA_NAME` NOT IN (SELECT `TABLE_SCHEMA` FROM `information_schema`.`TABLES`)
				AND `SCHEMA_NAME` NOT IN (SELECT `EVENT_SCHEMA` FROM `information_schema`.`EVENTS`)
				AND `SCHEMA_NAME` NOT IN (SELECT `ROUTINE_SCHEMA` FROM `information_schema`.`ROUTINES`)
				AND `SCHEMA_NAME` NOT IN (SELECT `TRIGGER_SCHEMA` FROM `information_schema`.`TRIGGERS`);
	
	DECLARE CONTINUE HANDLER
		FOR NOT FOUND
		SET `eof` = TRUE;
	
	-- for each empty db
	-- a fail is triggered with db name
	OPEN `crs_sch`;
	`lp_sch`:
	LOOP
		FETCH NEXT FROM `crs_sch`
			INTO `sch_name`;
		
		IF `eof` IS TRUE THEN
			LEAVE `lp_sch`;
		END IF;
		
		CALL `stk_unit`.assert_true(
				FALSE,
				CONCAT('Empty database: `', `sch_name`, '`')
			);
	END LOOP;
	CLOSE `crs_sch`;
END;


-- Test if there are empty tables
CREATE PROCEDURE test_empty_tables()
	LANGUAGE SQL
	COMMENT 'Test if there are empty tables'
BEGIN
	-- end for `crs_tabs`
	DECLARE `eof`       BOOLEAN  DEFAULT FALSE;
	-- empty table is sch_name.tab_name
	DECLARE `sch_name`  TEXT     DEFAULT NULL;
	DECLARE `tab_name`  TEXT     DEFAULT NULL;
	
	-- cursor which finds unused engines
	DECLARE `crs_tabs` CURSOR FOR
		SELECT `TABLE_SCHEMA`, `TABLE_NAME`
			FROM `information_schema`.`TABLES`
			WHERE `TABLE_ROWS` = 0
				-- empty tabs using following engines are ok
				AND `ENGINE` NOT IN ('MEMORY', 'BLACKHOLE', 'MRG_MyISAM')
				-- exlude system schemas
				AND `TABLE_SCHEMA` NOT IN ('mysql', 'information_schema', 'performance_schema', 'test');
	
	DECLARE CONTINUE HANDLER
		FOR NOT FOUND
		SET `eof` = TRUE;
	
	-- for each empty table (row returned by `crs_tabs`)
	-- a fail is triggered with table info
	OPEN `crs_tabs`;
	`lp_tabs`:
	LOOP
		FETCH NEXT FROM `crs_tabs`
			INTO `sch_name`, `tab_name`;
		
		IF `eof` IS TRUE THEN
			LEAVE `lp_tabs`;
		END IF;
		
		CALL `stk_unit`.assert_true(
				FALSE,
				CONCAT('Empty table: `', `sch_name`, '`.`', `tab_name`, '`')
			);
	END LOOP;
	CLOSE `crs_tabs`;
END;


-- Test if there are frammented tables
CREATE PROCEDURE test_frammented_tables()
	LANGUAGE SQL
	COMMENT 'Test if there are frammented tables'
BEGIN
	-- end for `crs_tabs`
	DECLARE `eof` BOOLEAN  DEFAULT FALSE;
	-- empty table is sch_name.tab_name
	DECLARE `tab_name`     TEXT     DEFAULT NULL;
	DECLARE `data_length`  TEXT     DEFAULT NULL;
	DECLARE `data_free`    TEXT     DEFAULT NULL;
	
	-- cursor which finds unused engines
	DECLARE `crs_tabs` CURSOR FOR
		SELECT
				CONCAT('`', `TABLE_SCHEMA`, '`.`', `TABLE_NAME`, '`'),
				CONCAT(ROUND(`DATA_LENGTH` / 1048576, 3), ' MB'),
				CONCAT(ROUND(`DATA_FREE`   / 1048576, 3), ' MB')
			FROM `information_schema`.`TABLES`
			WHERE
				-- exclude system db (not test)
				`TABLE_SCHEMA` NOT IN ('information_schema', 'performance_schema', 'mysql')
				-- exclude tabled with no free data
				AND `DATA_FREE` > 0
				-- exclude little tables;
				-- this also avoids 0 and NULL
				AND `DATA_LENGTH` > 500
				-- look for DATA_FREE higher than n%(data_length);
				AND `DATA_FREE` > (`DATA_LENGTH` * 0.5);
	
	DECLARE CONTINUE HANDLER
		FOR NOT FOUND
		SET `eof` = TRUE;
	
	OPEN `crs_tabs`;
	`lp_tabs`:
	LOOP
		FETCH NEXT FROM `crs_tabs`
			INTO `tab_name`, `data_length`, `data_free`;
		
		IF `eof` IS TRUE THEN
			LEAVE `lp_tabs`;
		END IF;
		
		CALL `stk_unit`.assert_true(
				FALSE,
				CONCAT(
						'Warning: table ', `tab_name`, ' is frammented: ',
						'Data Lengt: ', `data_length`, '; Free Data: ', `data_free`, '.'
					)
			);
	END LOOP;
	CLOSE `crs_tabs`;
END;


-- Test if there are 2 triggers on same action type (before insert, after insert).
-- A Stored Procedure could save performances and gather code in one place.
-- (But a BEFORE Trigger could assure data integrity, if users have INSERT right)
CREATE PROCEDURE test_many_triggers()
	LANGUAGE SQL
	COMMENT 'Look for 2 triggers on same schema.table.action'
BEGIN
	DECLARE `eof`       BOOLEAN  DEFAULT FALSE;
	-- trigger info
	DECLARE `sch_name`  TEXT     DEFAULT NULL;
	DECLARE `tab_name`  TEXT     DEFAULT NULL;
	DECLARE `evt_type`  TEXT     DEFAULT NULL;
	
	-- cursor which finds problematic triggers
	DECLARE `crs_trg` CURSOR FOR
		SELECT `TRIGGER_SCHEMA`, `EVENT_OBJECT_TABLE`, `EVENT_MANIPULATION`
			FROM `information_schema`.`TRIGGERS`
			GROUP BY `TRIGGER_SCHEMA`, `EVENT_OBJECT_TABLE`, `EVENT_MANIPULATION`
			HAVING COUNT(*) > 1;
	
	DECLARE CONTINUE HANDLER
		FOR NOT FOUND
		SET `eof` = TRUE;
	
	OPEN `crs_trg`;
	`lp_crs`:
	LOOP
		FETCH NEXT FROM `crs_trg`
			INTO `sch_name`, `tab_name`, `evt_type`;
		
		IF `eof` IS TRUE THEN
			LEAVE `lp_crs`;
		END IF;
		
		CALL `stk_unit`.assert_true(
				FALSE,
				CONCAT(
					'2 triggers on: `', `sch_name`, '`.`', `tab_name`, '`, action: `', `evt_type`, '`. ',
					'Tip: use Stored Procedure'
				)
			);
	END LOOP;
	CLOSE `crs_trg`;
END;


-- Test if Events are used but scheduler is disabled
CREATE PROCEDURE test_scheduler()
	LANGUAGE SQL
	COMMENT 'Test if Events are used while scheduler is disabled'
BEGIN
	-- if some Events are defined, Event Scheduler is not supposed to be OFF
	-- http://dev.mysql.com/doc/refman/5.5/en/server-system-variables.html#sysvar_event_scheduler
	CALL `stk_unit`.assert_false(
			@@global.event_scheduler LIKE 'OFF'
			AND EXISTS (SELECT 1 FROM `information_schema`.`EVENTS`),
			'Warning: events were found but Event Scheduler is disabled'
		);
END;


-- Test for non-active Events that could be simply forgotten
CREATE PROCEDURE test_nonactive_events()
	LANGUAGE SQL
	COMMENT 'Look for non-active events'
BEGIN
	DECLARE `eof` BOOLEAN DEFAULT FALSE;
	-- event info
	DECLARE `sch_name`    TEXT       DEFAULT '';
	DECLARE `evt_name`    TEXT       DEFAULT '';
	DECLARE `evt_status`  TEXT       DEFAULT NULL;  -- disabled?
	DECLARE `evt_ends`    TIMESTAMP  DEFAULT NULL;  -- recurring
	DECLARE `evt_exec`    TIMESTAMP  DEFAULT NULL;  -- one time
	-- should fail?
	DECLARE `fail` BOOLEAN DEFAULT FALSE;
	-- fail comment
	DECLARE `msg` TEXT DEFAULT NULL;
	
	DECLARE `crs_test` CURSOR FOR
		SELECT
			`EVENT_SCHEMA`, `EVENT_NAME`, `STATUS`, `ENDS`, `EXECUTE_AT`
			FROM `information_schema`.`EVENTS`
			WHERE
				-- disabled events
				`STATUS` = 'DISABLED'
				-- past events
				OR `ENDS` < NOW() -- recurring events
				OR `EXECUTE_AT` < NOW(); -- one time events
	
	DECLARE CONTINUE HANDLER
		FOR NOT FOUND
		SET `eof` = TRUE;
	
	OPEN `crs_test`;
	`lp_test`:
	LOOP
		FETCH NEXT FROM `crs_test`
			INTO `sch_name`, `evt_name`, `evt_status`, `evt_ends`, `evt_exec`;
		
		IF `eof` IS TRUE THEN
			LEAVE `lp_test`;
		END IF;
		
		-- reset fail
		SET `fail`  = FALSE;
		SET `msg`   = '';
		
		-- is past?
		IF IFNULL(`evt_ends`, `evt_exec`) < NOW() THEN
			SET `fail` = TRUE;
			SET `msg` =
				CONCAT(
						'Warning: event `', `sch_name`, '`.`', `evt_name`, '` ',
						'is past'
					);
		END IF;
		
		-- is disabled?
		IF `evt_status` LIKE 'DISABLED' THEN
			IF `fail` IS TRUE THEN
				-- is also past?
				SET `msg` = CONCAT(`msg`, ' and disabled');
			ELSE
				-- just disabled
				SET `fail` = TRUE;
				SET `msg` =
					CONCAT(
							'Warning: event `', `sch_name`, '`.`', `evt_name`, '` ',
							'is disabled'
						);
			END IF;
		END IF;
		
		CALL `stk_unit`.assert_false(`fail`, `msg`);
	END LOOP;
	CLOSE `crs_test`;
END;


-- restore session variables
SET @@session.SQL_MODE = @__stk_u_old_SQL_MODE;
SET @__stk_u_old_SQL_MODE = NULL;
SET @@session.sql_warnings = @__stk_u_old_sql_warnings;
SET @__stk_u_old_sql_warnings = NULL;
SET @@session.sql_notes = @__stk_u_old_sql_notes;
SET @__stk_u_old_sql_notes = NULL;
SET @@session.unique_checks = @__stk_u_old_unique_checks;
SET @__stk_u_old_unique_checks = NULL;
SET @@session.foreign_key_checks = @__stk_u_old_foreign_key_checks;
SET @__stk_u_old_foreign_key_checks = NULL;
SET /*!50200  @@session.innodb_strict_mode = @__stk_u_old_innodb_strict_mode, */  @__stk_u_tmp = NULL;
SET /*M!      @@session.innodb_strict_mode = @__stk_u_old_innodb_strict_mode, */  @__stk_u_tmp = NULL;
SET @__stk_u_old_innodb_strict_mode = NULL;


||
DELIMITER ;
