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


DELIMITER ||

##begin


-- make the server as strict as possible
-- TO-DO: ONLY_FULL_GROUP_BY
SET @__stk_u_old_SQL_MODE = @@session.SQL_MODE;
SET @@session.SQL_MODE = 'ERROR_FOR_DIVISION_BY_ZERO,NO_ZERO_DATE,NO_ZERO_IN_DATE,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION,STRICT_ALL_TABLES,STRICT_TRANS_TABLES';
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



-- here go test suites
CREATE DATABASE IF NOT EXISTS `stk_suite`;

-- create & select main db
CREATE DATABASE IF NOT EXISTS `stk_unit`;
USE `stk_unit`;



-- tables


DROP TABLE IF EXISTS `dbug_log`;
DROP TABLE IF EXISTS `config`;
DROP TABLE IF EXISTS `test_results`;
DROP TABLE IF EXISTS `test_run`;



-- here one can insert debug messages
CREATE TABLE `dbug_log`
(
	`id`          MEDIUMINT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`timestamp`   TIMESTAMP/*M!50300(6)*/ NOT NULL DEFAULT CURRENT_TIMESTAMP  COMMENT 'Entry timestamp',
	`connection`  BIGINT UNSIGNED                                             COMMENT 'Thread that logged this',
	`msg`         CHAR(255) NOT NULL DEFAULT ''                               COMMENT 'Debug message'
)
	ENGINE   = 'MyISAM';

-- Configuration options.
-- If test_case IS NULL they're global, else they're associated to a TC.
-- TC-level options overwrite global ones, when their TC runs.
-- All options can be TC-level, even if it may not make sense.
-- Invalid options are not written here.
CREATE TABLE `config`
(
	`var_key`    CHAR(10)  NOT NULL DEFAULT ''    COMMENT 'Name of the conf var',
	`var_val`    CHAR(10)  NOT NULL DEFAULT ''    COMMENT 'Current value',
	`test_case`  CHAR(64)  NOT NULL DEFAULT ''    COMMENT 'TC the value applies to; empty=global',
	UNIQUE INDEX `uni_key` (`var_key`, `test_case`)
)
	ENGINE    = 'MyISAM';

-- MySQL has not Aria;
-- putting a whole statement in an executable comment won't work on some versions.
ALTER TABLE `stk_unit`.`dbug_log`
	/*M!
		ENGINE          = 'Aria',
		TRANSACTIONAL   = 0,
		PAGE_CHECKSUM   = 0,
		TABLE_CHECKSUM  = 0,
	*/
		MIN_ROWS  = 0,
		COMMENT   = 'Can be used to log debug messages';

ALTER TABLE `stk_unit`.`config`
	/*M!
		ENGINE          = 'Aria',
		TRANSACTIONAL   = 1,
		PAGE_CHECKSUM   = 0,
		TABLE_CHECKSUM  = 1,
	*/
		MIN_ROWS  = 4,
		DEFAULT CHARACTER SET = ascii,
		COLLATE   = ascii_bin,
		COMMENT   = 'Config variables: global & tc-level';

-- default options
TRUNCATE TABLE `config`; -- dont delete this
INSERT INTO `config` (`var_key`, `var_val`, `test_case`)
	VALUES
		('dbug',        '0',     ''),
		('show_err',    '0',     ''),
		('out_format',  'text',  ''),
		('auto_clean',  '2',     '');

-- test execution data
CREATE TABLE `test_run`
(
	`id`          MEDIUMINT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`timestamp`   TIMESTAMP/*M!50300(6)*/ NOT NULL DEFAULT CURRENT_TIMESTAMP  COMMENT 'TR start timestamp',
	`run_by`      BIGINT UNSIGNED NOT NULL DEFAULT 0                          COMMENT 'Id of connection that run test',
	`tr_type`     ENUM('TC', 'TS') NOT NULL                                   COMMENT 'TC or TS',
	`tr_name`     CHAR(64) NOT NULL DEFAULT ''                                COMMENT 'TC/TS name',
	`complete`    BOOL NOT NULL DEFAULT FALSE                                 COMMENT 'Tells if TR is completed',
	INDEX `idx_tr` (`tr_name`, `tr_type`)
)
	ENGINE   = 'InnoDB',
	COMMENT = 'Test cases/suites runs';

-- results of single tests (not cases or suites)
CREATE TABLE `test_results`
(
	`id`          MEDIUMINT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
	`timestamp`   TIMESTAMP/*M!50300(6)*/ NOT NULL DEFAULT  CURRENT_TIMESTAMP,
	`run_by`      BIGINT UNSIGNED NOT NULL DEFAULT 0        COMMENT 'Connectio that run test',
	`test_run`    MEDIUMINT UNSIGNED NOT NULL DEFAULT 0     COMMENT 'FK to test_run',
	`test_case`   CHAR(64) NOT NULL DEFAULT ''              COMMENT 'Database',
	`base_test`   CHAR(64) NOT NULL DEFAULT ''              COMMENT 'Procedure name',
	`assert_num`  MEDIUMINT UNSIGNED NOT NULL DEFAULT 0     COMMENT 'Test-level assert prog number',
	`results`     ENUM('fail', 'pass', 'exception') NOT NULL DEFAULT 'fail' COMMENT 'pass = ok, fail = assert failed, exception = unexpected error',
	`msg`         CHAR(255) NOT NULL DEFAULT ''             COMMENT 'Fail/error message',
	INDEX `unq_results` (`results`),
	CONSTRAINT `fk_test_results_test_run`
		FOREIGN KEY `fk_test_run` (`test_run`)
		REFERENCES `stk_unit`.`test_run` (`id`)
		ON DELETE CASCADE
)
	ENGINE   = 'InnoDB',
	COMMENT  = 'Results of individual tests';


-- test_results with only most recent runs
CREATE OR REPLACE VIEW `last_test_results` AS
	SELECT *
		FROM `test_results`
		WHERE `test_run` = (SELECT MAX(`id`) FROM `test_run`)
		ORDER BY `id` ASC;

-- last_test_results with only failed + exceptions
CREATE OR REPLACE VIEW `last_test_results_bad` AS
	SELECT *
		FROM `last_test_results`
		WHERE `results` <> 'pass'
		ORDER BY `id` ASC;

-- test_results of each test's last run
CREATE OR REPLACE VIEW `recent_test_results` AS
	SELECT *
		FROM `test_results`
		WHERE `test_run` IN (SELECT MAX(`id`) FROM `test_run` GROUP BY `tr_type`, `tr_name`)
		ORDER BY `test_run` DESC, `id` ASC;

-- recent_test_results with only failed + exceptions
CREATE OR REPLACE VIEW `recent_test_results_bad` AS
	SELECT *
		FROM `recent_test_results`
		WHERE `results` <> 'pass'
		ORDER BY `id` ASC;

-- summary with only most recent test run
CREATE OR REPLACE VIEW `last_test_summary` AS
	SELECT
		(SELECT COUNT(*) FROM `last_test_results`) AS `total`,
		(SELECT COUNT(*) FROM `last_test_results` WHERE `results` = 'pass') AS `pass`,
		(SELECT COUNT(*) FROM `last_test_results` WHERE `results` = 'fail') AS `fail`,
		(SELECT COUNT(*) FROM `last_test_results` WHERE `results` = 'exception') AS `exception`;

-- summary of each test's last run (in a relational form)
CREATE OR REPLACE VIEW `recent_test_summary_relational` AS
	SELECT
			`test_case`, `test_run`, `results`, COUNT(*) AS `number`
		FROM `recent_test_results`
		GROUP BY `test_run`, `results`;

-- summary of each test's last run (in a readable form)
CREATE OR REPLACE VIEW `recent_test_summary` AS
	SELECT
			`test_run`,
			IF( (SELECT `number` FROM `recent_test_summary_relational` r_rel
			                 WHERE r_rel.`test_run` = r_read.`test_run` AND `results` = 'pass'),
				(SELECT `number` FROM `recent_test_summary_relational` r_rel
			                 WHERE r_rel.`test_run` = r_read.`test_run` AND `results` = 'pass'),
				0) AS `pass`,
			IF( (SELECT `number` FROM `recent_test_summary_relational` r_rel
			                 WHERE r_rel.`test_run` = r_read.`test_run` AND `results` = 'fail'),
				(SELECT `number` FROM `recent_test_summary_relational` r_rel
			                 WHERE r_rel.`test_run` = r_read.`test_run` AND `results` = 'fail'),
				0) AS `fail`,
			IF( (SELECT `number` FROM `recent_test_summary_relational` r_rel
			                 WHERE r_rel.`test_run` = r_read.`test_run` AND `results` = 'exception'),
				(SELECT `number` FROM `recent_test_summary_relational` r_rel
			                 WHERE r_rel.`test_run` = r_read.`test_run` AND `results` = 'exception'),
				0) AS `exception`,
			(SELECT SUM(`number`) FROM `recent_test_summary_relational` r_rel
			                 WHERE r_rel.`test_run` = r_read.`test_run`)
				AS `total`
		FROM      `recent_test_summary_relational` r_read
		GROUP BY  `test_run`;

/*
	The following VIEWs have the same style as information_schems
*/

-- Test Cases (databases called test_*)
CREATE OR REPLACE VIEW `TEST_CASE` AS
	SELECT `SCHEMA_NAME` AS `TEST_CASE_NAME`
		FROM `information_schema`.`SCHEMATA`
		WHERE `SCHEMA_NAME` LIKE BINARY 'test\_%';

-- Base Tests (SProcs called test_* in test databases)
CREATE OR REPLACE VIEW `BASE_TEST` AS
	SELECT
			r.`ROUTINE_NAME`     AS `BASE_TEST_NAME`,
			r.`ROUTINE_SCHEMA`   AS `TEST_CASE`,
			r.`CREATED`          AS `CREATED`,
			r.`LAST_ALTERED`     AS `LAST_ALTERED`,
			r.`SQL_MODE`         AS `SQL_MODE`,
			r.`DEFINER`          AS `DEFINER`,
			r.`ROUTINE_COMMENT`  AS `BASE_TEST_COMMENT`
		FROM        `information_schema`.`SCHEMATA` s
		INNER JOIN  `information_schema`.`ROUTINES` r
			ON      r.`ROUTINE_SCHEMA` = s.`SCHEMA_NAME`
		/*!50500 LEFT JOIN `information_schema`.`PARAMETERS` p
			ON r.`ROUTINE_NAME` = p.`SPECIFIC_NAME` */
		WHERE s.`SCHEMA_NAME`     LIKE BINARY 'test\_%'
			AND r.`ROUTINE_NAME`  LIKE BINARY 'test\_%'
			AND r.`ROUTINE_TYPE`  = 'PROCEDURE'
			/*!50500 AND p.`PARAMETER_NAME` IS NULL */;

-- Stored Routines which are in a TC but are not BTs
CREATE OR REPLACE VIEW `TEST_CASE_HELPER` AS
	SELECT
			r.`ROUTINE_NAME`     AS `BASE_TEST_NAME`,
			r.`ROUTINE_SCHEMA`   AS `TEST_CASE`,
			r.`CREATED`          AS `CREATED`,
			r.`LAST_ALTERED`     AS `LAST_ALTERED`,
			r.`SQL_MODE`         AS `SQL_MODE`,
			r.`DEFINER`          AS `DEFINER`,
			r.`ROUTINE_COMMENT`  AS `BASE_TEST_COMMENT`
		FROM        `information_schema`.`SCHEMATA` s
		INNER JOIN  `information_schema`.`ROUTINES` r
			ON      r.`ROUTINE_SCHEMA` = s.`SCHEMA_NAME`
		/*!50500 LEFT JOIN `information_schema`.`PARAMETERS` p
			ON r.`ROUTINE_NAME` = p.`SPECIFIC_NAME` */
		WHERE s.`SCHEMA_NAME`     LIKE BINARY 'test\_%'
			AND NOT (
				r.`ROUTINE_NAME`  LIKE BINARY 'test\_%'
				AND r.`ROUTINE_TYPE`  = 'PROCEDURE'
				/*!50500 AND p.`PARAMETER_NAME` IS NULL */
			);

-- Test Suites (Procedures in db 'test_suite')
CREATE OR REPLACE VIEW `TEST_SUITE` AS
	SELECT
			r.`ROUTINE_NAME`     AS `TEST_SUITE_NAME`,
			r.`CREATED`          AS `CREATED`,
			r.`LAST_ALTERED`     AS `LAST_ALTERED`,
			r.`SQL_MODE`         AS `SQL_MODE`,
			r.`DEFINER`          AS `DEFINER`,
			r.`ROUTINE_COMMENT`  AS `SUITE_COMMENT`
		FROM `information_schema`.`ROUTINES` r
		/*!50500 LEFT JOIN `information_schema`.`PARAMETERS` p
			ON r.`SPECIFIC_NAME` = p.`SPECIFIC_NAME` */
		WHERE r.`ROUTINE_SCHEMA` LIKE 'stk_suite'
			AND r.`ROUTINE_TYPE` = 'PROCEDURE'
			/*!50500 AND p.`PARAMETER_NAME` IS NULL */;

-- summary of each test's last run (in a relational form)
CREATE OR REPLACE VIEW `my_dbug_log` AS
	SELECT
			`timestamp`, `msg`
		FROM `dbug_log`
		WHERE `connection` = (SELECT `connection` FROM `dbug_log` ORDER BY `id` DESC LIMIT 1)
		ORDER BY `id` ASC;



-- stored routines



-- make sure that obsolete Routines dont exist in current installation.
-- these have only been in trunk for now.
DROP FUNCTION IF EXISTS `test_suite_show`;
DROP FUNCTION IF EXISTS `test_case_show`;
DROP FUNCTION IF EXISTS `test_run_show`;
DROP PROCEDURE IF EXISTS `check_expect`;
DROP PROCEDURE IF EXISTS `xml_replace`;


-- TODO: Move this into LibSQL
DROP FUNCTION IF EXISTS `ns_str`;
CREATE FUNCTION ns_str(`val` TEXT)
	RETURNS TEXT
	DETERMINISTIC
	NO SQL
	LANGUAGE SQL
	COMMENT 'NULL-safe: return quoted val, or ''NULL'' if is NULL'
BEGIN
	IF val IS NULL THEN
		RETURN 'NULL';
	ELSE
		RETURN QUOTE(val);
	END IF;
END;

-- TODO: Move this into LibSQL
DROP FUNCTION IF EXISTS `quote_name`;
CREATE FUNCTION quote_name(`id` TEXT)
	RETURNS TEXT
	DETERMINISTIC
	NO SQL
	LANGUAGE SQL
	COMMENT 'Return a quoted identifier (if NULL, id is empty)'
BEGIN
	IF `id` IS NULL THEN
		RETURN '``';
	ELSE
		RETURN CONCAT('`', REPLACE(`id`, '`', '``'), '`');
	END IF;
END;

-- TODO: Move this into LibSQL
DROP FUNCTION IF EXISTS `xml_encode`;
CREATE FUNCTION xml_encode(`str` TEXT)
	RETURNS TEXT
	DETERMINISTIC
	NO SQL
	LANGUAGE SQL
	COMMENT 'Return a XML string with entities'
BEGIN
	RETURN REPLACE(
		REPLACE(
			REPLACE(
				REPLACE(
					REPLACE(
								str, '&', '&amp;'
							),
							"'", '&apos;'
						),
						'"', '&quot;'
					),
					'>', '&gt;'
				),
			'<', '&lt;'
			);
END;

-- TO-DO: Move this into LibSQL
DROP PROCEDURE IF EXISTS `dyn_cursor`;
CREATE PROCEDURE `dyn_cursor`(IN `query` TEXT, IN `db` CHAR(64), IN `lock_name` CHAR(64), IN `timeout` TINYINT UNSIGNED)
	NO SQL
	LANGUAGE SQL
	COMMENT 'Lock and View for dyn cursor'
BEGIN
	-- output from GET_LOCK()
	DECLARE lock_res TINYINT UNSIGNED;
	
	-- error in query
	DECLARE CONTINUE HANDLER
		FOR SQLEXCEPTION
	BEGIN
		/*!50500
			SIGNAL SQLSTATE VALUE '45000' SET
				MESSAGE_TEXT  = '[STK/Unit.dyn_lock] Dynamic SQL returned an error';
		*/
		DO NULL;
	END;
	
	-- get lock or exit with err
	SET lock_res = GET_LOCK(`lock_name`, IFNULL(`timeout`, 5));
	IF lock_res IS NULL THEN
		/*!50500
			SIGNAL SQLSTATE VALUE '45000' SET
				MESSAGE_TEXT  = '[STK/Unit.dyn_lock] Could not acquire lock: Unknown error';
		*/
		DO NULL;
	ELSEIF lock_res = 0 THEN
		/*!50500
			SIGNAL SQLSTATE VALUE '45000' SET
				MESSAGE_TEXT  = '[STK/Unit.dyn_lock] Could not acquire lock: Timeout expired';
		*/
		DO NULL;
	END IF;
	
	-- create dynamic view
	SET @__stk_u_dyn_sql = CONCAT('CREATE OR REPLACE VIEW `', `db`, '`.`', `lock_name`, '` AS ', `query`, ';');
	PREPARE __stk_u_stmt_dyn_view FROM @__stk_u_dyn_sql;
	SET @__stk_u_dyn_sql = NULL;
	EXECUTE __stk_u_stmt_dyn_view;
	DEALLOCATE PREPARE __stk_u_stmt_dyn_view;
END;

DROP PROCEDURE IF EXISTS `show_test_suites`;
CREATE PROCEDURE `show_test_suites`(IN `pattern` TEXT)
	NO SQL
	LANGUAGE SQL
	COMMENT 'SHOW TS with name matching specified pattern (if not NULL)'
BEGIN
	IF `pattern` IS NULL THEN
		SELECT * FROM `stk_unit`.`TEST_SUITE`;
	ELSE
		SELECT * FROM `stk_unit`.`TEST_SUITE` WHERE `TEST_SUITE_NAME` LIKE `pattern`;
	END IF;
END;

DROP PROCEDURE IF EXISTS `show_test_cases`;
CREATE PROCEDURE `show_test_cases`(IN `pattern` TEXT)
	NO SQL
	LANGUAGE SQL
	COMMENT 'SHOW TC with name matching specified pattern (if not NULL)'
BEGIN
	IF `pattern` IS NULL THEN
		SELECT * FROM `stk_unit`.`TEST_CASE`;
	ELSE
		SELECT * FROM `stk_unit`.`TEST_CASE` WHERE `TEST_CASE_NAME` LIKE `pattern`;
	END IF;
END;

DROP PROCEDURE IF EXISTS `show_base_tests`;
CREATE PROCEDURE `show_base_tests`(IN `tc` TEXT, IN `pattern` TEXT)
	NO SQL
	LANGUAGE SQL
	COMMENT 'SHOW BT from tc matching pattern (both can be NULL)'
BEGIN
	IF `pattern` IS NULL THEN
		SELECT * FROM `stk_unit`.`BASE_TEST`
			WHERE IF(`tc` IS NULL, TRUE, `TEST_CASE` = `tc`);
	ELSE
		SELECT * FROM `stk_unit`.`BASE_TEST`
			WHERE
				IF(`tc` IS NULL, TRUE, `TEST_CASE` = `tc`)
				AND `BASE_TEST_NAME` LIKE `pattern`;
	END IF;
END;

DROP FUNCTION IF EXISTS `test_run_is_complete`;
CREATE FUNCTION test_run_is_complete(`rid` MEDIUMINT UNSIGNED)
	RETURNS BOOL
	NOT DETERMINISTIC
	READS SQL DATA
	LANGUAGE SQL
	COMMENT 'Return wether the TR is completed'
BEGIN
	DECLARE res MEDIUMINT UNSIGNED;
	
	SELECT `complete` FROM `stk_unit`.`test_run` WHERE `id` = rid INTO res;
	
	IF res IS NULL THEN
		/*!50500
			SIGNAL SQLSTATE VALUE '45000' SET
				MESSAGE_TEXT  = '[STK/Unit.test_run_is_complete] Id not found';
		*/
		RETURN NULL;
	END IF;
	
	RETURN res;
END;

-- test_run_summary() contains general code which applies to TS and TC.
-- test_suite_summary() and test_case_summary() are easier for the user
-- and are just bridges to test_run_summary().
-- Same logic applies to test_run_report(), test_suite_report() and test_case_report()

-- return human-readable TR result.
-- tr_type is 'TS' or 'TC' (case insensitive)
-- tr_name is the name of TS or TC
DROP FUNCTION IF EXISTS `test_run_summary`;
CREATE FUNCTION test_run_summary(`p_tr_type` CHAR(2), `p_tr_name` CHAR(64))
	RETURNS TEXT
	NOT DETERMINISTIC
	READS SQL DATA
	LANGUAGE SQL
	COMMENT 'Private. Return human-readable Test Run results'
BEGIN
	-- output buffer
	DECLARE buf         TEXT     DEFAULT '';
	-- output format
	DECLARE out_format  CHAR(4)  DEFAULT `stk_unit`.config_get('out_format');
	-- TR id
	DECLARE rid         MEDIUMINT UNSIGNED;
	
	-- summary
	DECLARE num_pass  MEDIUMINT UNSIGNED;
	DECLARE num_fail  MEDIUMINT UNSIGNED;
	DECLARE num_exc   MEDIUMINT UNSIGNED;
	
	-- adjust p_tr_type and return error if not valid
	
	SET p_tr_type = UPPER(p_tr_type);
	
	IF p_tr_type NOT IN ('TC', 'TS') THEN
		/*!50500
			SIGNAL SQLSTATE VALUE '45000' SET
				MESSAGE_TEXT  = '[STK/Unit.test_run_summary] Invalid test type';
		*/
		RETURN NULL;
	END IF;
	
	-- get run id and throw error if not exists
	
	SELECT
			`id`
		FROM `test_run`
		WHERE `tr_name` = p_tr_name
		      AND `tr_type` = p_tr_type
		ORDER BY `id` DESC
		LIMIT 1
		INTO rid;
	
	IF rid IS NULL THEN
		/*!50500
			SIGNAL SQLSTATE VALUE '45000' SET
				MESSAGE_TEXT  = '[STK/Unit.test_run_summary] Cannot find specified test';
		*/
		RETURN NULL;
	END IF;
	
	-- make summary
	
	SELECT
	           `pass`, `fail`, `exception`
		FROM   `recent_test_summary`
		WHERE  `test_run` = rid
		INTO   num_pass, num_fail, num_exc;
	
	IF out_format = 'text' THEN
		SET buf = CONCAT(
				'\n',
					IF(p_tr_type = 'TC', 'Test Case: ', 'Test Suite: '), p_tr_name,
				'\n',
					'Id: ', IFNULL(rid, ''),
				'\n',
					'Completed: ', IF(test_run_is_complete(rid) IS TRUE, 'YES', 'NO'),
				'\n',
					IFNULL(num_pass, ''),  ' passes, ',
					IFNULL(num_fail, ''),  ' fails, ',
					IFNULL(num_exc, ''),   ' exceptions',
				'\n'
			);
	ELSEIF out_format = 'html' THEN
		SET buf = CONCAT(
				'\n',
				'<h1>',
					IF(p_tr_type = 'TC', 'Test Case: ', 'Test Suite: '), p_tr_name,
				'</h1>\n',
				'<h2>', '\n',
					'\tId: ', IFNULL(rid, ''), '<br/>\n',
					'\tCompleted: ', IF(test_run_is_complete(rid) IS TRUE, 'YES', 'NO'), '\n',
				'</h2>\n',
				'<p>',
					IFNULL(num_pass, ''),  ' passes, ',
					IFNULL(num_fail, ''),  ' fails, ',
					IFNULL(num_exc, ''),   ' exceptions',
				'</p>',
				'\n'
			);
	END IF;
	
	RETURN buf;
END;

-- return human-readable TS result.
-- ts_name is the name of TS
DROP FUNCTION IF EXISTS `test_suite_summary`;
CREATE FUNCTION test_suite_summary(`ts_name` CHAR(64))
	RETURNS TEXT
	NOT DETERMINISTIC
	READS SQL DATA
	LANGUAGE SQL
	COMMENT 'Return human-readable Test Suite results'
BEGIN
	-- auto-retreive
	IF `ts_name` IS NULL OR `ts_name` = '' THEN
		SET `ts_name` = @__stk_u_last_ts;
	END IF;
	
	RETURN (SELECT test_run_summary('TS', `ts_name`));
END;

-- return human-readable TC result.
-- tc_name is the name of TC
DROP FUNCTION IF EXISTS `test_case_summary`;
CREATE FUNCTION test_case_summary(`tc_name` CHAR(64))
	RETURNS TEXT
	NOT DETERMINISTIC
	READS SQL DATA
	LANGUAGE SQL
	COMMENT 'Return human-readable Test Case results'
BEGIN
	-- auto-retreive
	IF `tc_name` IS NULL OR `tc_name` = '' THEN
		SET `tc_name` = @__stk_u_last_tc;
	END IF;
	
	RETURN (SELECT test_run_summary('TC', `tc_name`));
END;

DROP PROCEDURE IF EXISTS `test_run_report`;
CREATE PROCEDURE test_run_report(IN `p_tr_type` CHAR(2), IN `p_tr_name` CHAR(64), INOUT `str` TEXT)
	READS SQL DATA
	LANGUAGE SQL
	COMMENT 'Private. Show TR summary & reports on Fails & Exceptions, if any'
`__stk_u_lbl_bad`:
BEGIN
	-- end-of-data handler
	DECLARE eof         BOOL DEFAULT FALSE;
	-- output format
	DECLARE out_format  CHAR(4)  DEFAULT `stk_unit`.config_get('out_format');
	-- TR id
	DECLARE rid         MEDIUMINT UNSIGNED;
	
	-- bad results info
	DECLARE bad_tc       TEXT;
	DECLARE bad_bt       TEXT;
	DECLARE bad_results  TEXT;
	DECLARE bad_num      TEXT;
	DECLARE bad_msg      TEXT;
	
	-- dynamic cursor to read bad results
	DECLARE __stk_u_crs_bad CURSOR FOR
		SELECT * FROM `stk_unit`.`__stk_u_dyn_view`;
	
	DECLARE CONTINUE HANDLER
		FOR NOT FOUND
		SET eof = TRUE;
	
	-- adjust p_tr_type and return error if not valid
	
	SET p_tr_type = UPPER(p_tr_type);
	
	IF p_tr_type NOT IN ('TC', 'TS') THEN
		/*!50500
			SIGNAL SQLSTATE VALUE '45000' SET
				MESSAGE_TEXT  = '[STK/Unit.test_run_report] Invalid test type';
		*/
		LEAVE `__stk_u_lbl_bad`;
	END IF;
	
	-- get run id and throw error if not exists
	
	SELECT
			`id`
		FROM `test_run`
		WHERE `tr_name` = p_tr_name
		      AND `tr_type` = p_tr_type
		ORDER BY `id` DESC
		LIMIT 1
		INTO rid;
	
	IF rid IS NULL THEN
		/*!50500
			SIGNAL SQLSTATE VALUE '45000' SET
				MESSAGE_TEXT  = '[STK/Unit.test_run_report] Cannot find specified test';
		*/
		LEAVE `__stk_u_lbl_bad`;
	END IF;
	
	-- get summary, first
	
	SET str = stk_unit.test_run_summary(p_tr_type, p_tr_name);
	
	-- open dynamic cursor, to get bad results
	CALL `dyn_cursor`(
			CONCAT(
					'SELECT `test_case`, `base_test`, `results`, `assert_num`, `msg` ',
					'FROM `stk_unit`.`recent_test_results_bad` WHERE `test_run` = ', rid, ' ',
					'ORDER BY `id` ASC;'
				),
			'stk_unit',
			'__stk_u_dyn_view',
			5
		);
	OPEN `__stk_u_crs_bad`;
	DO RELEASE_LOCK('__stk_u_dyn_view');
	
	`__stk_u_rbad`: LOOP
		FETCH `__stk_u_crs_bad` INTO bad_tc, bad_bt, bad_results, bad_num, bad_msg;
		
		-- end of test case?
		IF eof IS TRUE THEN
			LEAVE `__stk_u_rbad`;
		END IF;
		
		-- print bad row?
		IF bad_results <> 'pass' THEN
			IF out_format = 'text' THEN
				SET str = CONCAT(
								str,
							'\n',
								UPPER(bad_results), ': ',
								quote_name(bad_tc), '.', quote_name(bad_bt), ' ',
								'[', bad_num, ']',
								IFNULL(CONCAT(' - ', bad_msg), '')
					);
			ELSEIF out_format = 'html' THEN
				SET str = CONCAT(
							str,
							'\n',
							'<p>',
								'<strong>', xml_encode(UPPER(bad_results)), '</strong>: ',
								'<code>', quote_name(xml_encode(bad_tc)), '.', quote_name(xml_encode(bad_bt)), '</code> ',
								'[', bad_num, ']',
								IFNULL(CONCAT(' - ', xml_encode(bad_msg)), ''),
							'</p>'
							/*!50500 COLLATE 'utf8_general_ci' */ -- avoid collation mismmatch between ascii and utf8
					);
			END IF;
		END IF;
	END LOOP;
	
	CLOSE `__stk_u_crs_bad`;
	
	-- make string appear in the client
	IF @`__stk_u_silent` IS NULL THEN
		SELECT str AS `report`;
	END IF;
END;

DROP PROCEDURE IF EXISTS `test_suite_report`;
CREATE PROCEDURE test_suite_report(IN `name` CHAR(64), INOUT `str` TEXT)
	READS SQL DATA
	LANGUAGE SQL
	COMMENT 'Show TS summary & reports on Fails & Exceptions, if any'
BEGIN
	-- auto-retreive
	IF `name` IS NULL OR `name` = '' THEN
		SET `name` = @__stk_u_last_ts;
	END IF;
	
	CALL test_run_report('TS', `name`, `str`);
END;

DROP PROCEDURE IF EXISTS `test_case_report`;
CREATE PROCEDURE test_case_report(IN `name` CHAR(64), INOUT `str` TEXT)
	READS SQL DATA
	LANGUAGE SQL
	COMMENT 'Show TC summary & reports on Fails & Exceptions, if any'
BEGIN
	-- auto-retreive
	IF `name` IS NULL OR `name` = '' THEN
		SET `name` = @__stk_u_last_tc;
	END IF;
	
	CALL test_run_report('TC', `name`, `str`);
END;

-- returns wether specified Stored Procedure exists
DROP FUNCTION IF EXISTS `procedure_exists`;
CREATE FUNCTION procedure_exists(sp_schema CHAR(64), sp_name CHAR(64))
	RETURNS BOOL
	NOT DETERMINISTIC
	READS SQL DATA
	LANGUAGE SQL
	COMMENT 'Returns wether specified Stored Procedure exists'
BEGIN
	RETURN EXISTS (
		SELECT `ROUTINE_NAME`
			FROM `information_schema`.`ROUTINES`
			WHERE      `ROUTINE_SCHEMA`  = `sp_schema`
				  AND  `ROUTINE_NAME`    = `sp_name`
				  AND  `ROUTINE_TYPE`    = 'PROCEDURE'
		);
END;

-- calls `sp_schema`.`sp_name`()
DROP PROCEDURE IF EXISTS `procedure_call`;
CREATE PROCEDURE procedure_call(IN sp_schema CHAR(64), IN sp_name CHAR(64))
	LANGUAGE SQL
	COMMENT 'Calls `sp_schema`.`sp_name`()'
BEGIN
	SET @__stk_u_call_tc = CONCAT('CALL `', sp_schema, '`.`', sp_name, '`();');
	
	PREPARE __stk_u_stmt_call FROM @__stk_u_call_tc;
	SET @__stk_u_call_tc = NULL;
	EXECUTE __stk_u_stmt_call;
	DEALLOCATE PREPARE __stk_u_stmt_call;
END;

-- set a configuration option:
-- global if no test is running in the current session,
-- tc-level if a tc is running (running_test temptable)
DROP PROCEDURE IF EXISTS `config_set`;
CREATE PROCEDURE config_set(
		opt_key CHAR(64) CHARACTER SET 'ascii' /*!50500 COLLATE 'ascii_bin' */,
		opt_val CHAR(10) CHARACTER SET 'ascii' /*!50500 COLLATE 'ascii_bin' */
		)
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Set a configuration option'
`__stk_u_main_block`:
BEGIN
	-- names are ci
	SET opt_key = LOWER(opt_key);
	
	-- validate name & value.
	-- if there is an error, generate error or exit procedure
	IF opt_key = 'out_format' THEN
		-- format exists?
		SET opt_val = LOWER(opt_val);
		IF opt_val NOT IN ('text', 'html') THEN
			/*!50500
				SIGNAL SQLSTATE VALUE '45000' SET
					MESSAGE_TEXT  = '[STK/Unit.config_set] Invalid format';
			*/
			LEAVE `__stk_u_main_block`;
		END IF;
	ELSEIF opt_key IN ('show_err', 'dbug') THEN
		-- valid pseudo-boolean? convert it to 1/0 string
		SET opt_val = LOWER(opt_val);
		IF opt_val IN ('1', 'true', 'yes', 'on') THEN
			SET opt_val = '1';
		ELSEIF opt_val IN ('0', 'false', 'no', 'off') THEN
			SET opt_val = '0';
		ELSE
			/*!50500
				SIGNAL SQLSTATE VALUE '45000' SET
					MESSAGE_TEXT  = '[STK/Unit.config_set] Invalid boolean';
			*/
			LEAVE `__stk_u_main_block`;
		END IF;
	ELSEIF opt_key = 'auto_clean' THEN
		SET opt_val = LOWER(opt_val);
		IF opt_val NOT IN ('0', '1', '2') THEN
			/*!50500
				SIGNAL SQLSTATE VALUE '45000' SET
					MESSAGE_TEXT  = '[STK/Unit.config_set] Invalid auto_clean';
			*/
			LEAVE `__stk_u_main_block`;
		END IF;
	ELSE
		-- invalid option name
		/*!50500
			SIGNAL SQLSTATE VALUE '45000' SET
				MESSAGE_TEXT  = '[STK/Unit.config_set] Invalid Configuration Option';
		*/
		LEAVE `__stk_u_main_block`;
	END IF;
	
	REPLACE
		INTO      `stk_unit`.`config`
		SET       `var_key`    = opt_key,
		          `var_val`    = opt_val,
				  `test_case`  = IFNULL(@__stk_u_tc, '');
END `__stk_u_main_block`;

-- When a TR is run for a TS or TC, the older TR's for the same TS or TC become obsolete.
-- These Routines deletes old results.

DROP PROCEDURE IF EXISTS `results_clean_all`;
CREATE PROCEDURE results_clean_all()
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Delete all obsolete results'
BEGIN
	-- list of id's of TRs to delete
	DECLARE `id_list` TEXT DEFAULT '';
	-- backup for @@session.foreign_key_checks
	DECLARE `fk_checks` TEXT DEFAULT @@session.foreign_key_checks;
	
	-- log that we're here
	IF config_get('dbug') = '1' THEN
		CALL `stk_unit`.dbug_log('results_clean_all');
	END IF;
	
	-- get list of obsolete TRs
	SELECT GROUP_CONCAT(`id` SEPARATOR ', ')
		FROM `test_run`
		WHERE `id` NOT IN (
				-- recent TRs
				SELECT MAX(`id`) FROM `test_run` GROUP BY `tr_type`, `tr_name`
			)
		INTO `id_list`;
	
	-- log which ids have been found
	IF config_get('dbug') = '1' THEN
		CALL `stk_unit`.dbug_log(CONCAT('Obsolete id list: ', IFNULL(`id_list`, '')));
	END IF;
	
	IF `id_list` IS NOT NULL THEN
		-- compose DELETE
		SET @__stk_u_clean = CONCAT(
				'DELETE FROM `test_run` WHERE `id` IN (', `id_list`, ');'
			);
		
		-- log delete statement
		IF config_get('dbug') = '1' THEN
			CALL `stk_unit`.dbug_log(CONCAT('AUTOCLEAN stmt: ', IFNULL(@__stk_u_clean, '')));
		END IF;
		
		-- we need foreign_key_checks
		SET @@session.foreign_key_checks = TRUE;
		
		-- exec DELETE
		PREPARE __stk_stmt_clean FROM @__stk_u_clean;
		SET @__stk_u_clean = NULL;
		EXECUTE __stk_stmt_clean;
		DEALLOCATE PREPARE __stk_stmt_clean;
		
		-- restore foreign_key_checks
		SET `fk_checks` = @@session.foreign_key_checks;
	END IF;
END;

DROP PROCEDURE IF EXISTS `results_clean_tr`;
CREATE PROCEDURE results_clean_tr(`p_tr_type` CHAR(2), `p_tr_name` CHAR(64))
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Delete obsolete versions of specified TR'
`__stk_u_rct`:
BEGIN
	-- list of id's of TRs to delete
	DECLARE `id_list` TEXT DEFAULT '';
	-- backup for @@session.foreign_key_checks
	DECLARE `fk_checks` TEXT DEFAULT @@session.foreign_key_checks;
	
	-- log that we're here
	IF config_get('dbug') = '1' THEN
		CALL `stk_unit`.dbug_log('results_clean_tr(''', IFNULL(p_tr_type, ''), ''', ''', IFNULL(p_tr_name, ''), ''')');
	END IF;
	
	-- validate p_tr_type
	SET p_tr_type = LOWER(p_tr_type);
	IF p_tr_type NOT IN('ts', 'tc') THEN
		/*!50500
			SIGNAL SQLSTATE VALUE '45000' SET
				MESSAGE_TEXT  = '[STK/Unit.results_clean_tr] Unknown TR type';
		*/
		LEAVE `__stk_u_rct`;
	END IF;
	
	-- get list of obsolete TRs
	SELECT GROUP_CONCAT(`id` SEPARATOR ', ')
		FROM `test_run`
		WHERE `id` NOT IN (
				-- recent TRs
				SELECT MAX(`id`) FROM `test_run` WHERE `tr_name` = p_tr_name AND `tr_type` = p_tr_type
			)
		INTO `id_list`;
	
	-- log which ids have been found
	IF config_get('dbug') = '1' THEN
		CALL `stk_unit`.dbug_log(CONCAT('Obsolete id list: ', IFNULL(`id_list`, '')));
	END IF;
	
	IF `id_list` IS NOT NULL THEN
		-- compose DELETE
		SET @__stk_u_clean = CONCAT(
				'DELETE FROM `test_run` WHERE `id` IN (', `id_list`, ') ',
					'AND `tr_name` = ''', `p_tr_name`, ''' AND `tr_type` = ''', `p_tr_type`, ''';'
			);
		
		-- log delete statement
		IF config_get('dbug') = '1' THEN
			CALL `stk_unit`.dbug_log(CONCAT('AUTOCLEAN stmt: ', IFNULL(@__stk_u_clean, '')));
		END IF;
		
		-- we need foreign_key_checks
		SET @@session.foreign_key_checks = TRUE;
		
		-- exec DELETE
		PREPARE __stk_stmt_clean FROM @__stk_u_clean;
		SET @__stk_u_clean = NULL;
		EXECUTE __stk_stmt_clean;
		DEALLOCATE PREPARE __stk_stmt_clean;
		
		-- restore foreign_key_checks
		SET `fk_checks` = @@session.foreign_key_checks;
	ELSE
		-- not found; check if test exists or raise error
		IF `p_tr_type` = 'tc' THEN
			IF NOT EXISTS (SELECT `TEST_CASE_NAME` FROM `stk_unit`.`TEST_CASE` WHERE `TEST_CASE_NAME` = `p_tr_name`) THEN
				/*!50500
					SIGNAL SQLSTATE VALUE '45000' SET
						MESSAGE_TEXT  = '[STK/Unit.results_clean_tr] Test Case does not exist';
				*/
				LEAVE `__stk_u_rct`;
			END IF;
		ELSE
			IF NOT EXISTS (SELECT `TEST_SUITE_NAME` FROM `stk_unit`.`TEST_SUITE` WHERE `TEST_SUITE_NAME` = `p_tr_name`) THEN
			/*!50500
				SIGNAL SQLSTATE VALUE '45000' SET
					MESSAGE_TEXT  = '[STK/Unit.results_clean_tr] Test Suite does not exist';
			*/
			LEAVE `__stk_u_rct`;
			END IF;
		END IF;
	END IF;
END;

-- gets configuration option value:
-- tc-level if a tc is running, else global
DROP FUNCTION IF EXISTS `config_get`;
CREATE FUNCTION config_get(`opt_key` CHAR(64) CHARACTER SET 'ascii' /*!50500 COLLATE 'ascii_bin' */)
	RETURNS CHAR(10)
	NOT DETERMINISTIC
	READS SQL DATA
	LANGUAGE SQL
	COMMENT 'Return a configuration option'
BEGIN
	-- option value goes here
	DECLARE `tc` CHAR(64) DEFAULT IFNULL(@__stk_u_tc, '');
	
	-- if opt_key is not there, return NULL
	DECLARE CONTINUE HANDLER
		FOR NOT FOUND
		RETURN NULL;
	
	RETURN (
			SELECT `var_val`
				FROM `stk_unit`.`config`
				WHERE `var_key` = `opt_key`
				ORDER BY `test_case` <> `tc`
				LIMIT 1
		);
END;

-- write a debug message in the dbug_log table
-- TO-DO: move this into STK/DBUG
DROP PROCEDURE IF EXISTS `dbug_log`;
CREATE PROCEDURE dbug_log(IN msg CHAR(255))
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Write a debug message in the dbug_log table'
BEGIN
	INSERT INTO `stk_unit`.`dbug_log` (`msg`, `connection`) VALUES (msg, CONNECTION_ID());
END;

-- add an entry to test_results
DROP PROCEDURE IF EXISTS `log_result`;
CREATE PROCEDURE log_result(IN res CHAR(9), IN msg CHAR(255))
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Internal. Add an entry to test_results'
BEGIN
	-- log status info & error
	INSERT INTO `stk_unit`.`test_results`
			(`test_run`, `run_by`, `base_test`, `test_case`, `assert_num`, `results`, `msg`)
		VALUES
			(@__stk_u_tr, CONNECTION_ID(), @__stk_u_bt, @__stk_u_tc, @__stk_u_assert_num + 1, res, msg);
END;

-- Check if last run Test Case had an unsitified expected exception.
-- If it had, records the error in test_results.
DROP PROCEDURE IF EXISTS `check_expect`;
CREATE PROCEDURE check_expect()
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Check if last run Test Case had an unsitified expected exception'
BEGIN
	IF (SELECT COUNT(*) > 0 FROM `stk_unit`.`expect` WHERE `action` = 'expect') THEN
		CALL `stk_unit`.log_result('fail', 'Expected Exception');
		
		-- delete expectation
		TRUNCATE TABLE `stk_unit`.`expect`;
	END IF;
END;

-- handles any kind of exceptions
DROP PROCEDURE IF EXISTS `handle_exception`;
CREATE PROCEDURE handle_exception()
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Internal. RESIGNAL mu errors, log user errors.'
BEGIN
	-- this helps to find out when a problem happened
	IF config_get('dbug') = '1' THEN
		CALL `stk_unit`.dbug_log('Exception found');
	END IF;
	
	IF @__stk_u_throw_error = TRUE THEN
		-- framework error. re-throw
		/*!50500
			RESIGNAL;
		*/
		DO NULL;
	ELSEIF (SELECT COUNT(*) > 0 FROM `stk_unit`.`expect`) THEN
		-- exception was expected.
		-- trigger a pass
		CALL `stk_unit`.log_result('pass', 'Satisfied Excpectation');
		-- expected/ignored exception
		TRUNCATE TABLE `stk_unit`.`expect`;
	ELSE
		-- uncatched exception.
		-- if 'show_err' option is set, RESIGNAL (if possible);
		-- else, gracefully record an uncatched exception
		IF `stk_unit`.config_get('show_err') <> '0' THEN
			-- framework error. re-throw
			/*!50500
				RESIGNAL;
			*/
			DO NULL;
		END IF;
		CALL `stk_unit`.log_result('exception', 'Uncatched Exception');
	END IF;
END;

-- drop temptables
DROP PROCEDURE IF EXISTS `deinit_status`;
CREATE PROCEDURE deinit_status()
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Internal. Drop temptables used for test status'
BEGIN
	-- mark TR as completed
	UPDATE `stk_unit`.`test_run`
		SET `complete` = TRUE
		WHERE `id` = @__stk_u_tr;
	
	-- remember info about last test run, to allow automatic retreive.
	-- @__stk_u_last_tr_type and @__stk_u_last_tr_name are not used now,
	-- but could be useful shortcuts in the future.
	IF @__stk_u_ts IS NOT NULL THEN
		SET @__stk_u_last_ts       = @__stk_u_ts;
		SET @__stk_u_last_tr_type  = 'ts';
		SET @__stk_u_last_tr_name  = @__stk_u_ts;
	ELSE
		SET @__stk_u_last_tc       = @__stk_u_tc;
		SET @__stk_u_last_tr_type  = 'tc';
		SET @__stk_u_last_tr_name  = @__stk_u_tc;
	END IF;
	
	-- delete obsolete results
	IF `stk_unit`.config_get('auto_clean') = '1' THEN
		IF @__stk_u_ts IS NOT NULL THEN
			CALL `stk_unit`.results_clean_tr('ts', @__stk_u_ts);
		ELSE
			CALL `stk_unit`.results_clean_tr('tc', @__stk_u_tc);
		END IF;
	ELSEIF `stk_unit`.config_get('auto_clean') = '2' THEN
		CALL `stk_unit`.results_clean_all();
	END IF;
	
	-- clean temptables
	DROP TEMPORARY TABLE IF EXISTS `stk_unit`.`expect`;
	
	-- if later in this session a TC is called,
	-- it must know that it is not part of a TS.
	SET @__stk_u_ts = NULL;
	
	-- if a TS is called later in this session,
	-- it must know that no TC is in progress
	SET @__stk_u_tc = NULL;
	
	-- clean all variables, just to be safe
	SET @__stk_u_tr           = NULL;
	SET @__stk_u_bt           = NULL;
	SET @__stk_u_assert_num   = NULL;
	SET @__stk_u_res          = NULL;
END;

-- create and fill vars table
DROP PROCEDURE IF EXISTS `init_status`;
CREATE PROCEDURE init_status()
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Internal. Create and fill temp tables'
BEGIN
	-- TODO: set locally max_heap_table_size to very low value (< 10?)
	-- exceptions ignored/expected
	DROP TEMPORARY TABLE IF EXISTS `stk_unit`.`expect`;
	CREATE TEMPORARY TABLE `stk_unit`.`expect` (
		`action`      ENUM('ignore', 'expect') NOT NULL      COMMENT 'ignore = no effect; expect = must happen',
		`errno`       SMALLINT UNSIGNED NULL DEFAULT NULL    COMMENT 'Exception code'
	)
		ENGINE    = 'MEMORY',
		DEFAULT CHARACTER SET = ascii,
		COLLATE   = ascii_bin,
		MAX_ROWS  = 1,
		COMMENT   = 'Exceptions to be ignored/expected';
	
	-- write and read test_run
	INSERT INTO `stk_unit`.`test_run`
			(`run_by`, `tr_type`, `tr_name`)
		VALUES
			(
				CONNECTION_ID(),
				IF(@__stk_u_ts IS NOT NULL, 'TS','TC'),
				COALESCE(@__stk_u_ts, @__stk_u_tc)
			);
	SET @__stk_u_tr = (SELECT LAST_INSERT_ID());
	
	-- init other vars
	SET @__stk_u_bt          = NULL;
	SET @__stk_u_assert_num  = NULL;
	SET @__stk_u_res         = NULL;
END;

-- execute a Test Case
DROP PROCEDURE IF EXISTS `test_case_run`;
CREATE PROCEDURE test_case_run(IN tc CHAR(64))
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Run a Test Case'
`__stk_u_tcrun`:
BEGIN
	-- bt name
	DECLARE base_test     CHAR(64) DEFAULT NULL;
	-- end-of-data handler
	DECLARE eof           BOOL DEFAULT FALSE;
	-- number of tests found
	DECLARE num_tests     MEDIUMINT UNSIGNED DEFAULT 0;
	-- existing user functions
	DECLARE exists_set_up     BOOL DEFAULT FALSE;
	DECLARE exists_tear_down  BOOL DEFAULT FALSE;
	
	
	-- query to get tests from TC
	DECLARE `__stk_u_crs_tables` CURSOR FOR
		SELECT `BASE_TEST_NAME`
			FROM `stk_unit`.`BASE_TEST`
			WHERE `TEST_CASE` = IF(tc IS NULL OR tc = '', @__stk_u_last_tc, tc)
			ORDER BY `BASE_TEST_NAME`;
	
	DECLARE CONTINUE HANDLER
		FOR NOT FOUND
		SET eof = TRUE;
	
	DECLARE CONTINUE HANDLER
		FOR SQLWARNING, SQLEXCEPTION
		CALL `stk_unit`.handle_exception();
	
	
	SET @__stk_u_throw_error = TRUE;
	
	-- auto-retreive
	IF tc IS NULL OR tc = '' THEN
		SET tc = @__stk_u_last_tc;
	END IF;
	
	-- check if TC exists
	IF NOT EXISTS (SELECT `TEST_CASE_NAME` FROM `stk_unit`.`TEST_CASE` WHERE `TEST_CASE_NAME` = tc) THEN
		/*!50500
			SIGNAL SQLSTATE VALUE '45000' SET
				MESSAGE_TEXT  = '[STK/Unit.test_case_run] Test Case not found';
		*/
		LEAVE `__stk_u_tcrun`;
	END IF;
	
	-- need to remember current test case
	-- even if we're in a TS
	SET @__stk_u_tc = tc;
	
	-- log TC name
	IF config_get('dbug') = '1' THEN
		CALL `stk_unit`.dbug_log(CONCAT('Starting TC: `', IFNULL(tc, ''), '`'));
	END IF;
	
	-- create temptables
	-- (if we're not inside a TS)
	IF @__stk_u_ts IS NULL THEN
		CALL `stk_unit`.init_status();
	END IF;
	
	-- prepare all tests
	IF procedure_exists(tc, 'before_all_tests') = TRUE THEN
		IF config_get('dbug') = '1' THEN
			CALL `stk_unit`.dbug_log(CONCAT('Calling: `', IFNULL(tc, ''), '`.`before_all_tests`'));
		END IF;
		CALL procedure_call(tc, 'before_all_tests');
	END IF;
	
	-- do set_up() and tear_down() exist?
	SET exists_set_up     = procedure_exists(tc, 'set_up');
	SET exists_tear_down  = procedure_exists(tc, 'tear_down');
	
	-- get tests
	OPEN `__stk_u_crs_tables`;
	`__stk_u_do_test`: LOOP
		FETCH `__stk_u_crs_tables` INTO base_test;
		
		-- must be accessible from log_result()
		SET @__stk_u_bt = base_test;
		
		-- end of test case?
		IF eof = TRUE THEN
			LEAVE `__stk_u_do_test`;
		END IF;
		SET num_tests = num_tests + 1;
		
		-- log test name
		IF config_get('dbug') = '1' THEN
			CALL `stk_unit`.dbug_log(CONCAT('Found BT: `', IFNULL(base_test, ''), '`'));
		END IF;
		
		-- test errors must not be RESIGNALed
		SET @__stk_u_throw_error = FALSE;
		-- reset unit test runs
		SET @__stk_u_assert_num = 0;
		
		-- run set_up()
		IF exists_set_up = TRUE THEN
			IF config_get('dbug') = '1' THEN
				CALL `stk_unit`.dbug_log(CONCAT('Calling: `', IFNULL(tc, ''), '`.`set_up`'));
			END IF;
			CALL procedure_call(tc, 'set_up');
		END IF;
		
		-- run next test
		IF config_get('dbug') = '1' THEN
			CALL `stk_unit`.dbug_log(CONCAT('Calling BT: `', IFNULL(tc, ''), '`.`', IFNULL(base_test, ''), '`'));
		END IF;
		CALL procedure_call(tc, base_test);
		
		-- log that BT was completely executed
		IF config_get('dbug') = '1' THEN
			CALL `stk_unit`.dbug_log(CONCAT('Exited BT: `', IFNULL(base_test, ''), '`'));
		END IF;
		
		-- last test has an unsitisfied expected exception?
		CALL `stk_unit`.check_expect();
		
		-- run tear_down()
		IF exists_tear_down = TRUE THEN
			IF config_get('dbug') = '1' THEN
				CALL `stk_unit`.dbug_log(CONCAT('Calling: `', IFNULL(tc, ''), '`.`tear_down`'));
			END IF;
			CALL procedure_call(tc, 'tear_down');
		END IF;
	END LOOP;
	CLOSE `__stk_u_crs_tables`;
	
	-- log TC name
	IF config_get('dbug') = '1' THEN
		CALL `stk_unit`.dbug_log(CONCAT('Ending TC: `', IFNULL(tc, ''), '`'));
	END IF;
	
	-- clean after all tests
	IF procedure_exists(tc, 'after_all_tests') = TRUE THEN
		IF config_get('dbug') = '1' THEN
			CALL `stk_unit`.dbug_log(CONCAT('Calling: `', IFNULL(tc, ''), '`.`after_all_tests`'));
		END IF;
		CALL procedure_call(tc, 'after_all_tests');
	END IF;
	
	-- but if we're executing a TS, individual TC's
	-- must not create/drop status temptable
	IF @__stk_u_ts IS NULL THEN
		CALL `stk_unit`.deinit_status();
	END IF;
	
	-- no tests? error
	IF num_tests = 0 THEN
		-- SIGNAL a tests not found,
		-- that will be RESIGNALed
		SET @__stk_u_throw_error = TRUE;
		
		/*!50500
			SIGNAL SQLSTATE VALUE '45000' SET
				MESSAGE_TEXT  = '[STK/Unit.test_case_run] No tests found';
		*/
		LEAVE `__stk_u_tcrun`;
	END IF;
END;

-- execute a Test Suite
DROP PROCEDURE IF EXISTS `test_suite_run`;
CREATE PROCEDURE test_suite_run(IN ts CHAR(64))
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Run a Test Suite'
`__stk_u_tsrun`:
BEGIN
	-- automatic retreive
	IF ts IS NULL OR ts = '' THEN
		SET ts = @__stk_u_last_ts;
	END IF;
	
	-- log TS name
	IF config_get('dbug') = '1' THEN
		CALL `stk_unit`.dbug_log(CONCAT('Starting TS: `', IFNULL(ts, ''), '`'));
	END IF;
	
	IF procedure_exists('stk_suite', ts) = TRUE THEN
		-- remember TS name: TC must not init/deinit status
		SET @__stk_u_ts = ts;
		
		-- status initialized by TS, not individual TC's
		CALL `stk_unit`.init_status();
		
		-- execute TS
		IF config_get('dbug') = '1' THEN
			CALL `stk_unit`.dbug_log(CONCAT('Calling TS: `', IFNULL(ts, ''), '`'));
		END IF;
		SET @__stk_u_call = CONCAT('CALL `stk_suite`.`', ts, '`();');
		PREPARE __stk_stmt_call_ts FROM @__stk_u_call;
		SET @__stk_u_call = NULL;
		EXECUTE __stk_stmt_call_ts;
		DEALLOCATE PREPARE __stk_stmt_call_ts;
		
		-- log TS end before cleaning
		IF config_get('dbug') = '1' THEN
			CALL `stk_unit`.dbug_log(CONCAT('Ending TS: `', IFNULL(ts, ''), '`'));
		END IF;
		
		-- clean temptables.
		-- for now, TS's cannot be recursive
		CALL `stk_unit`.deinit_status();
	ELSE
		-- clean temptables even if somehint go wrong
		CALL `stk_unit`.deinit_status();
		
		-- TS not found, throw error
		/*!50500
			SIGNAL SQLSTATE VALUE '45000' SET
				MESSAGE_TEXT  = '[STK/Unit.test_suite_run] Test Suite not found';
		*/
		LEAVE `__stk_u_tsrun`;
	END IF;
END;


DROP PROCEDURE IF EXISTS `tc`;
CREATE PROCEDURE `tc`(IN `name` CHAR(64))
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Short for test_case_run() + test_case_report()'
BEGIN
	-- tell other Routines not to generate resultsets
	SET @`__stk_u_silent` = TRUE;
	-- exec test
	CALL `stk_unit`.`test_case_run`(`name`);
	-- get results, query them, and free memory
	CALL `stk_unit`.`test_case_report`(`name`, @`__stk_temp`);
	SELECT @`__stk_temp` AS `report`;
	SET @`__stk_temp` = NULL;
	SET @`__stk_u_silent` = NULL;
END;


DROP PROCEDURE IF EXISTS `ts`;
CREATE PROCEDURE `ts`(IN `name` CHAR(64))
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Short for test_case_run() + test_case_report()'
BEGIN
	-- tell other Routines not to generate resultsets
	SET @`__stk_u_silent` = TRUE;
	-- exec test
	CALL `stk_unit`.`test_suite_run`(`name`);
	-- get results, query them, and free memory
	CALL `stk_unit`.`test_suite_report`(`name`, @`__stk_temp`);
	SELECT @`__stk_temp` AS `report`;
	SET @`__stk_temp` = NULL;
	SET @`__stk_u_silent` = NULL;
END;



#
#	Exceptions
#

-- throw an error if there is already an expectation
DROP PROCEDURE IF EXISTS `no_double_expectation`;
CREATE PROCEDURE no_double_expectation()
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Internal. Raises an error if an expectation is already there'
BEGIN
	-- there was an expectarion already? error!
	IF EXISTS (SELECT 1 FROM `stk_unit`.`expect`) THEN
		-- this error must be RESIGNALed
		SET @__stk_u_throw_error = TRUE;
		
		-- raise error
		/*!50500
			SIGNAL SQLSTATE VALUE '45000' SET
			MESSAGE_TEXT  = '[STK/Unit] Only one expectation per Base Test is allowed';
		*/
	END IF;
END;

DROP PROCEDURE IF EXISTS `ignore_all_exceptions`;
CREATE PROCEDURE ignore_all_exceptions()
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Ignore all exceptions for this unit test'
BEGIN
	-- check that an expectation was not already there
	CALL `stk_unit`.no_double_expectation();
	
	-- insert new expectation
	INSERT INTO `stk_unit`.`expect`
		(`action`, `errno`)
		VALUES
		('ignore', NULL);
END;

DROP PROCEDURE IF EXISTS `expect_any_exception`;
CREATE PROCEDURE expect_any_exception()
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Except an exception for this unit test'
BEGIN
	-- check that an expectation was not already there
	CALL `stk_unit`.no_double_expectation();
	
	-- insert new expectation
	INSERT INTO `stk_unit`.`expect`
		(`action`, `errno`)
		VALUES
		('expect', NULL);
END;


#
#	Assertions
#

-- Low-level assertion.
-- This MUST be used by ALL assert_* Procedures to trigger
-- a Pass or a Fail.
-- However, this Procedure MUST NOT be called by test developers.
DROP PROCEDURE IF EXISTS `assert`;
CREATE PROCEDURE assert(IN `cond` TEXT, IN `msg` CHAR(255))
	LANGUAGE SQL
	MODIFIES SQL DATA
	COMMENT 'Internal. Low-level assertion'
BEGIN
	-- 'fail' or 'pass'
	DECLARE `cond_result` CHAR(9) DEFAULT NULL;
	
	-- msg must only be stored on fail
	IF `cond` <> '0' THEN
		SET `msg` = '';
		SET `cond_result` = 'pass';
	ELSE
		IF `msg` IS NULL THEN
			SET `msg` = CONCAT('assert() received: ', `stk_unit`.ns_str(`cond`));
		END IF;
		SET `cond_result` = 'fail';
	END IF;
	
	-- log status info & assert result
	CALL `stk_unit`.log_result(`cond_result`, `msg`);
	
	SET @__stk_u_assert_num = @__stk_u_assert_num + 1;
END;


-- The following asserts are meant to be invoked by the test developers.


DROP PROCEDURE IF EXISTS `assert_true`;
CREATE PROCEDURE assert_true(IN val TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the passed value is not FALSE'
BEGIN
	IF msg IS NULL THEN
		SET msg = CONCAT('Param 1 expected to be: TRUE; Received: ', `stk_unit`.ns_str(val));
	END IF;
	CALL `stk_unit`.assert(val, msg);
END;

DROP PROCEDURE IF EXISTS `assert_false`;
CREATE PROCEDURE assert_false(IN val TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the passed value is FALSE'
BEGIN
	IF msg IS NULL THEN
		SET msg = CONCAT('Param 1 expected to be: FALSE; Received: ', `stk_unit`.ns_str(val));
	END IF;
	CALL `stk_unit`.assert(val = FALSE, msg);
END;

DROP PROCEDURE IF EXISTS `assert_null`;
CREATE PROCEDURE assert_null(IN val TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the passed value is NULL'
BEGIN
	IF msg IS NULL THEN
		SET msg = CONCAT('Param 1 expected to be: NULL; Received: ', `stk_unit`.ns_str(val));
	END IF;
	CALL `stk_unit`.assert(val IS NULL, msg);
END;

DROP PROCEDURE IF EXISTS `assert_not_null`;
CREATE PROCEDURE assert_not_null(IN val TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the passed value is NOT NULL'
BEGIN
	IF msg IS NULL THEN
		SET msg = 'Param 1 expected to be: NOT NULL; Received: NULL';
	END IF;
	CALL `stk_unit`.assert(val IS NOT NULL, msg);
END;

DROP PROCEDURE IF EXISTS `assert_equals`;
CREATE PROCEDURE assert_equals(IN val1 TEXT, IN val2 TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the passed values are equal'
BEGIN
	IF msg IS NULL THEN
		SET msg = CONCAT('Param1 is: ', `stk_unit`.ns_str(val1), ' Param2 is: ', `stk_unit`.ns_str(val2));
	END IF;
	CALL `stk_unit`.assert(val1 = val2, msg);
END;

DROP PROCEDURE IF EXISTS `assert_not_equals`;
CREATE PROCEDURE assert_not_equals(IN val1 TEXT, IN val2 TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the passed values are different'
BEGIN
	IF msg IS NULL THEN
		SET msg = CONCAT('Param1 is: ', `stk_unit`.ns_str(val1), ' Param2 is: ', `stk_unit`.ns_str(val2));
	END IF;
	CALL `stk_unit`.assert(val1 <> val2, msg);
END;

DROP PROCEDURE IF EXISTS `assert_like`;
CREATE PROCEDURE assert_like(IN val1 TEXT, IN val2 TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the val1 LIKE val2'
BEGIN
	IF msg IS NULL THEN
		SET msg = CONCAT('Param1 is: ', `stk_unit`.ns_str(val1), ' Param2 is: ', `stk_unit`.ns_str(val2));
	END IF;
	CALL `stk_unit`.assert(val1 LIKE val2, msg);
END;

DROP PROCEDURE IF EXISTS `assert_not_like`;
CREATE PROCEDURE assert_not_like(IN val1 TEXT, IN val2 TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the val1 NOT LIKE val2'
BEGIN
	IF msg IS NULL THEN
		SET msg = CONCAT('Param1 is: ', `stk_unit`.ns_str(val1), ' Param2 is: ', `stk_unit`.ns_str(val2));
	END IF;
	CALL `stk_unit`.assert(val1 NOT LIKE val2, msg);
END;

DROP PROCEDURE IF EXISTS `assert_like_with_escape`;
CREATE PROCEDURE assert_like_with_escape(IN val1 TEXT, IN val2 TEXT, IN esc_chr CHAR(1), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the val1 LIKE val2 ESCAPE chr'
BEGIN
	IF msg IS NULL THEN
		SET msg = CONCAT('Param1 is: ', `stk_unit`.ns_str(val1), ' Param2 is: ', `stk_unit`.ns_str(val2),
			' Escape: ', `stk_unit`.ns_str(esc_chr));
	END IF;
	CALL `stk_unit`.assert(val1 LIKE val2 ESCAPE esc_chr, msg);
END;

DROP PROCEDURE IF EXISTS `assert_not_like_with_escape`;
CREATE PROCEDURE assert_not_like_with_escape(IN val1 TEXT, IN val2 TEXT, IN esc_chr CHAR(1), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the val1 NOT LIKE val2 ESCAPE chr'
BEGIN
	IF msg IS NULL THEN
		SET msg = CONCAT('Param1 is: ', `stk_unit`.ns_str(val1), ' Param2 is: ', `stk_unit`.ns_str(val2),
			' Escape: ', `stk_unit`.ns_str(esc_chr));
	END IF;
	CALL `stk_unit`.assert(val1 NOT LIKE val2 ESCAPE esc_chr, msg);
END;

DROP PROCEDURE IF EXISTS `assert_regexp`;
CREATE PROCEDURE assert_regexp(IN val1 TEXT, IN val2 TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the val1 REGEXP val2'
BEGIN
	IF msg IS NULL THEN
		SET msg = CONCAT('Param1 is: ', `stk_unit`.ns_str(val1), ' Param2 is: ', `stk_unit`.ns_str(val2));
	END IF;
	CALL `stk_unit`.assert(val1 REGEXP val2, msg);
END;

DROP PROCEDURE IF EXISTS `assert_not_regexp`;
CREATE PROCEDURE assert_not_regexp(IN val1 TEXT, IN val2 TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the val1 NOT REGEXP val2'
BEGIN
	IF msg IS NULL THEN
		SET msg = CONCAT('Param1 is: ', `stk_unit`.ns_str(val1), ' Param2 is: ', `stk_unit`.ns_str(val2));
	END IF;
	CALL `stk_unit`.assert(val1 NOT REGEXP val2, msg);
END;

DROP PROCEDURE IF EXISTS `assert_regexp_binary`;
CREATE PROCEDURE assert_regexp_binary(IN val1 TEXT, IN val2 TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the val1 REGEXP BINARY val2'
BEGIN
	IF msg IS NULL THEN
		SET msg = CONCAT('Param1 is: ', `stk_unit`.ns_str(val1), ' Param2 is: ', `stk_unit`.ns_str(val2));
	END IF;
	CALL `stk_unit`.assert(val1 REGEXP BINARY val2, msg);
END;

DROP PROCEDURE IF EXISTS `assert_not_regexp_binary`;
CREATE PROCEDURE assert_not_regexp_binary(IN val1 TEXT, IN val2 TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the val1 NOT REGEXP BINARY val2'
BEGIN
	IF msg IS NULL THEN
		SET msg = CONCAT('Param1 is: ', `stk_unit`.ns_str(val1), ' Param2 is: ', `stk_unit`.ns_str(val2));
	END IF;
	CALL `stk_unit`.assert(val1 NOT REGEXP BINARY val2, msg);
END;

DROP PROCEDURE IF EXISTS `assert_database_exists`;
CREATE PROCEDURE assert_database_exists(IN db CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the database called db exists'
BEGIN
	CALL `stk_unit`.assert(
			EXISTS (SELECT `SCHEMA_NAME` FROM `information_schema`.`SCHEMATA` WHERE `SCHEMA_NAME` = db),
			msg
		);
END;

DROP PROCEDURE IF EXISTS `assert_database_not_exists`;
CREATE PROCEDURE assert_database_not_exists(IN db CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the database called db not exists'
BEGIN
	CALL `stk_unit`.assert(
			NOT EXISTS (SELECT `SCHEMA_NAME` FROM `information_schema`.`SCHEMATA` WHERE `SCHEMA_NAME` = db),
			msg
		);
END;

DROP PROCEDURE IF EXISTS `assert_table_exists`;
CREATE PROCEDURE assert_table_exists(IN db CHAR(64), IN tab CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the database called db contains a table named tab'
BEGIN
	CALL `stk_unit`.assert(
			EXISTS (SELECT `TABLE_NAME` FROM `information_schema`.`TABLES` WHERE `TABLE_SCHEMA` = db AND `TABLE_NAME` = tab),
			msg
		);
END;

DROP PROCEDURE IF EXISTS `assert_table_not_exists`;
CREATE PROCEDURE assert_table_not_exists(IN db CHAR(64), IN tab CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that the database called db does not contain tab'
BEGIN
	CALL `stk_unit`.assert(
			NOT EXISTS (SELECT `TABLE_NAME` FROM `information_schema`.`TABLES` WHERE `TABLE_SCHEMA` = db AND `TABLE_NAME` = tab),
			msg
		);
END;

DROP PROCEDURE IF EXISTS `assert_view_exists`;
CREATE PROCEDURE assert_view_exists(IN db CHAR(64), IN viw CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that database db contains view viw'
BEGIN
	CALL `stk_unit`.assert(
			EXISTS (SELECT `TABLE_NAME` FROM `information_schema`.`VIEWS` WHERE `TABLE_SCHEMA` = db AND `TABLE_NAME` = viw),
			msg
		);
END;

DROP PROCEDURE IF EXISTS `assert_view_not_exists`;
CREATE PROCEDURE assert_view_not_exists(IN db CHAR(64), IN viw CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that database db does not contain view viw'
BEGIN
	CALL `stk_unit`.assert(
			NOT EXISTS (SELECT `TABLE_NAME` FROM `information_schema`.`VIEWS` WHERE `TABLE_SCHEMA` = db AND `TABLE_NAME` = viw),
			msg
		);
END;

DROP PROCEDURE IF EXISTS `assert_routine_exists`;
CREATE PROCEDURE assert_routine_exists(IN db CHAR(64), IN sr_name CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that database db contains routine sr_name'
BEGIN
	CALL `stk_unit`.assert(
			EXISTS (SELECT `SPECIFIC_NAME` FROM `information_schema`.`ROUTINES` WHERE `ROUTINE_SCHEMA` = db AND `SPECIFIC_NAME` = sr_name),
			msg
		);
END;

DROP PROCEDURE IF EXISTS `assert_routine_not_exists`;
CREATE PROCEDURE assert_routine_not_exists(IN db CHAR(64), IN sr_name CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that database db does not contain routine sr_name'
BEGIN
	CALL `stk_unit`.assert(
			NOT EXISTS (SELECT `SPECIFIC_NAME` FROM `information_schema`.`ROUTINES` WHERE `ROUTINE_SCHEMA` = db AND `SPECIFIC_NAME` = sr_name),
			msg
		);
END;

DROP PROCEDURE IF EXISTS `assert_event_exists`;
CREATE PROCEDURE assert_event_exists(IN db CHAR(64), IN ev CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that database db contains event ev'
BEGIN
	-- MySQL 5.0 has no events
	DECLARE not_supported BOOL DEFAULT TRUE;
	
	/*!50100
		CALL `stk_unit`.assert(
				EXISTS (SELECT `EVENT_NAME` FROM `information_schema`.`EVENTS` WHERE `EVENT_SCHEMA` = db AND `EVENT_NAME` = ev),
				msg
			);
		SET not_supported = FALSE;
	*/
	
	IF not_supported IS TRUE THEN
		CALL `stk_unit`.assert(FALSE, 'Current MySQL version does not support EVENTs');
	END IF;
END;

DROP PROCEDURE IF EXISTS `assert_event_not_exists`;
CREATE PROCEDURE assert_event_not_exists(IN db CHAR(64), IN ev CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that database db does not contain event ev'
BEGIN
	-- MySQL 5.0 has no events
	DECLARE not_supported BOOL DEFAULT TRUE;
	
	/*!50100
		CALL `stk_unit`.assert(
				NOT EXISTS (SELECT `EVENT_NAME` FROM `information_schema`.`EVENTS` WHERE `EVENT_SCHEMA` = db AND `EVENT_NAME` = ev),
				msg
			);
		SET not_supported = FALSE;
	*/
	
	IF not_supported IS TRUE THEN
		CALL `stk_unit`.assert(FALSE, 'Current MySQL version does not support EVENTs');
	END IF;
END;

DROP PROCEDURE IF EXISTS `assert_trigger_exists`;
CREATE PROCEDURE assert_trigger_exists(IN db CHAR(64), IN trig CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that database db contains trigger trig'
BEGIN
	CALL `stk_unit`.assert(
			EXISTS (SELECT `TRIGGER_NAME` FROM `information_schema`.`TRIGGERS` WHERE `TRIGGER_SCHEMA` = db AND `TRIGGER_NAME` = trig),
			msg
		);
END;

DROP PROCEDURE IF EXISTS `assert_trigger_not_exists`;
CREATE PROCEDURE assert_trigger_not_exists(IN db CHAR(64), IN trig CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that database db does not contain trigger trig'
BEGIN
	CALL `stk_unit`.assert(
			NOT EXISTS (SELECT `TRIGGER_NAME` FROM `information_schema`.`TRIGGERS` WHERE `TRIGGER_SCHEMA` = db AND `TRIGGER_NAME` = trig),
			msg
		);
END;

DROP PROCEDURE IF EXISTS `assert_column_exists`;
CREATE PROCEDURE assert_column_exists(IN db CHAR(64), IN tab CHAR(64), IN col CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that table tab in db contains column col'
BEGIN
	CALL `stk_unit`.assert(
		EXISTS (SELECT 1 FROM `information_schema`.`COLUMNS`
			WHERE `TABLE_SCHEMA` = db AND `TABLE_NAME` = tab AND `COLUMN_NAME` = col),
		msg);
END;

DROP PROCEDURE IF EXISTS `assert_column_not_exists`;
CREATE PROCEDURE assert_column_not_exists(IN `db` CHAR(64), IN `tab` CHAR(64), IN `col` CHAR(64), IN `msg` CHAR(255))
	LANGUAGE SQL
	MODIFIES SQL DATA
	COMMENT 'Assert that table tab in db does not contain column col'
BEGIN
	CALL `stk_unit`.`assert`(
		NOT EXISTS (SELECT `COLUMN_NAME` FROM `information_schema`.`COLUMNS`
			WHERE `TABLE_SCHEMA` = `db` AND `TABLE_NAME` = `tab` AND `COLUMN_NAME` = `col`),
		`msg`);
END;

DROP PROCEDURE IF EXISTS `assert_row_exists`;
CREATE PROCEDURE assert_row_exists(IN db CHAR(64), IN tab CHAR(64), IN col CHAR(64), IN val TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that table tab in db contains the specified col=val'
BEGIN
	-- @__stk_u_cmd_assert_row_exists will look like this:
	/*
			SELECT 'assert_temp' AS var_key EXISTS (
				SELECT 1
					FROM `db`.`tab`
					WHERE `col` = 'val'
					or:
					WHERE `col` IS NULL
			) INTO @__stk_u_res;
	*/
	
	-- compose query
	SET @__stk_u_cmd_assert_row_exists = CONCAT(
			'SELECT EXISTS (',
			'SELECT 1 FROM `', db, '`.`', tab, '` '
		);
	IF val IS NULL THEN
		SET @__stk_u_cmd_assert_row_exists = CONCAT(@__stk_u_cmd_assert_row_exists,
			'WHERE `', col, '` IS NULL');
	ELSE
		SET @__stk_u_cmd_assert_row_exists = CONCAT(@__stk_u_cmd_assert_row_exists,
			'WHERE `', col, '` = ''', val, '''');
	END IF;
	SET @__stk_u_cmd_assert_row_exists = CONCAT(@__stk_u_cmd_assert_row_exists,
		') INTO @__stk_u_res;');
	
	-- run query
	PREPARE __stk_u_stmt_assert_row_exists FROM @__stk_u_cmd_assert_row_exists;
	EXECUTE __stk_u_stmt_assert_row_exists;
	SET @__stk_u_cmd_assert_row_exists = NULL;
	DEALLOCATE PREPARE __stk_u_stmt_assert_row_exists;
	
	-- assert
	CALL `stk_unit`.assert(@__stk_u_res, msg);
	
	SET @__stk_u_res = NULL;
END;

DROP PROCEDURE IF EXISTS `assert_row_not_exists`;
CREATE PROCEDURE assert_row_not_exists(IN db CHAR(64), IN tab CHAR(64), IN col CHAR(64), IN val TEXT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that tab in db does not contain the specified col=val'
BEGIN
	-- @__stk_u_cmd_assert_row_exists will look like this:
	/*
			SELECT 'assert_temp' AS var_key NOT EXISTS (
				SELECT 1
					FROM `db`.`tab`
					WHERE `col` = 'val'
					or:
					WHERE `col` IS NULL
			) INTO @__stk_u_res;
	*/
	
	-- compose query
	SET @__stk_u_cmd_assert_row_exists = CONCAT(
			'SELECT NOT EXISTS (',
			'SELECT 1 FROM `', db, '`.`', tab, '` '
		);
	IF val IS NULL THEN
		SET @__stk_u_cmd_assert_row_exists = CONCAT(@__stk_u_cmd_assert_row_exists,
			'WHERE `', col, '` IS NULL');
	ELSE
		SET @__stk_u_cmd_assert_row_exists = CONCAT(@__stk_u_cmd_assert_row_exists,
			'WHERE `', col, '` = ''', val, '''');
	END IF;
	SET @__stk_u_cmd_assert_row_exists = CONCAT(@__stk_u_cmd_assert_row_exists,
		') INTO @__stk_u_res;');
	
	-- run query
	PREPARE __stk_u_stmt_assert_row_exists FROM @__stk_u_cmd_assert_row_exists;
	SET @__stk_u_cmd_assert_row_exists = NULL;
	EXECUTE __stk_u_stmt_assert_row_exists;
	DEALLOCATE PREPARE __stk_u_stmt_assert_row_exists;
	
	-- assert
	CALL `stk_unit`.assert(@__stk_u_res, msg);
	
	SET @__stk_u_res = NULL;
END;

DROP PROCEDURE IF EXISTS `assert_rows_count`;
CREATE PROCEDURE assert_rows_count(IN db CHAR(64), IN tab CHAR(64), IN num BIGINT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that table tab in db contains num rows'
BEGIN
	-- compose query
	SET @__stk_u_cmd_assert_rows_count = CONCAT(
			'SELECT COUNT(*) FROM `', db, '`.`', tab, '` INTO @__stk_u_res;'
		);
	
	-- run query
	PREPARE __stk_u_stmt_assert_rows_count FROM @__stk_u_cmd_assert_rows_count;
	SET @__stk_u_cmd_assert_rows_count = NULL;
	EXECUTE __stk_u_stmt_assert_rows_count;
	DEALLOCATE PREPARE __stk_u_stmt_assert_rows_count;
	
	-- assert
	CALL `stk_unit`.assert(@__stk_u_res = num, msg);
	
	SET @__stk_u_res = NULL;
END;

DROP PROCEDURE IF EXISTS `assert_table_empty`;
CREATE PROCEDURE assert_table_empty(IN db CHAR(64), IN tab CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that table tab in db is empty'
BEGIN
	-- compose query
	SET @__stk_u_cmd_assert_rows_count = CONCAT(
			'SELECT COUNT(*) FROM `', db, '`.`', tab, '` INTO @__stk_u_res;'
		);
	
	-- run query
	PREPARE __stk_u_stmt_assert_rows_count FROM @__stk_u_cmd_assert_rows_count;
	SET @__stk_u_cmd_assert_rows_count = NULL;
	EXECUTE __stk_u_stmt_assert_rows_count;
	DEALLOCATE PREPARE __stk_u_stmt_assert_rows_count;
	
	-- assert
	CALL `stk_unit`.assert(@__stk_u_res = 0, msg);
	
	SET @__stk_u_res = NULL;
END;

DROP PROCEDURE IF EXISTS `assert_table_not_empty`;
CREATE PROCEDURE assert_table_not_empty(IN db CHAR(64), IN tab CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that table tab in db is not empty'
BEGIN
	-- compose query
	SET @__stk_u_cmd_assert_rows_count = CONCAT(
			'SELECT COUNT(*) FROM `', db, '`.`', tab, '` INTO @__stk_u_res;'
		);
	
	-- run query
	PREPARE __stk_u_stmt_assert_rows_count FROM @__stk_u_cmd_assert_rows_count;
	SET @__stk_u_cmd_assert_rows_count = NULL;
	EXECUTE __stk_u_stmt_assert_rows_count;
	DEALLOCATE PREPARE __stk_u_stmt_assert_rows_count;
	
	-- assert
	CALL `stk_unit`.assert(@__stk_u_res <> 0, msg);
	
	SET @__stk_u_res = NULL;
END;

DROP PROCEDURE IF EXISTS `assert_field_count_distinct`;
CREATE PROCEDURE assert_field_count_distinct(IN db CHAR(64), IN tab CHAR(64), IN col CHAR(64), IN num BIGINT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that db.tab.col contains num unique values'
BEGIN
	-- compose query
	SET @__stk_u_cmd_assert_field = CONCAT(
			'SELECT COUNT(DISTINCT `', col, '`) FROM `', db, '`.`', tab, '` INTO @__stk_u_res;'
		);
	
	-- run query
	PREPARE __stk_u_stmt_assert_field FROM @__stk_u_cmd_assert_field;
	SET @__stk_u_cmd_assert_field = NULL;
	EXECUTE __stk_u_stmt_assert_field;
	DEALLOCATE PREPARE __stk_u_stmt_assert_field;
	
	-- assert
	CALL `stk_unit`.assert(@__stk_u_res = num, msg);
	
	SET @__stk_u_res = NULL;
END;

DROP PROCEDURE IF EXISTS `assert_field_min`;
CREATE PROCEDURE assert_field_min(IN db CHAR(64), IN tab CHAR(64), IN col CHAR(64), IN num BIGINT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that MIN(db.tab.col) = num'
BEGIN
	-- compose query
	SET @__stk_u_cmd_assert_field = CONCAT(
			'SELECT MIN(`', col, '`) FROM `', db, '`.`', tab, '` INTO @__stk_u_res;'
		);
	
	-- run query
	PREPARE __stk_u_stmt_assert_field FROM @__stk_u_cmd_assert_field;
	SET @__stk_u_cmd_assert_field = NULL;
	EXECUTE __stk_u_stmt_assert_field;
	DEALLOCATE PREPARE __stk_u_stmt_assert_field;
	
	-- assert
	CALL `stk_unit`.assert(@__stk_u_res = num, msg);
	
	SET @__stk_u_res = NULL;
END;

DROP PROCEDURE IF EXISTS `assert_field_max`;
CREATE PROCEDURE assert_field_max(IN db CHAR(64), IN tab CHAR(64), IN col CHAR(64), IN num BIGINT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that MAX(db.tab.col) = num'
BEGIN
	-- compose query
	SET @__stk_u_cmd_assert_field = CONCAT(
			'SELECT MAX(`', col, '`) FROM `', db, '`.`', tab, '` INTO @__stk_u_res;'
		);
	
	-- run query
	PREPARE __stk_u_stmt_assert_field FROM @__stk_u_cmd_assert_field;
	SET @__stk_u_cmd_assert_field = NULL;
	EXECUTE __stk_u_stmt_assert_field;
	DEALLOCATE PREPARE __stk_u_stmt_assert_field;
	
	-- assert
	CALL `stk_unit`.assert(@__stk_u_res = num, msg);
	
	SET @__stk_u_res = NULL;
END;

DROP PROCEDURE IF EXISTS `assert_field_avg`;
CREATE PROCEDURE assert_field_avg(IN db CHAR(64), IN tab CHAR(64), IN col CHAR(64), IN num BIGINT, IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that AVG(db.tab.col) = num'
BEGIN
	-- compose query
	SET @__stk_u_cmd_assert_field = CONCAT(
			'SELECT AVG(`', col, '`) FROM `', db, '`.`', tab, '` INTO @__stk_u_res;'
		);
	
	-- run query
	PREPARE __stk_u_stmt_assert_field FROM @__stk_u_cmd_assert_field;
	SET @__stk_u_cmd_assert_field = NULL;
	EXECUTE __stk_u_stmt_assert_field;
	DEALLOCATE PREPARE __stk_u_stmt_assert_field;
	
	-- assert
	CALL `stk_unit`.assert(@__stk_u_res = num, msg);
	
	SET @__stk_u_res = NULL;
END;

DROP PROCEDURE IF EXISTS `assert_sql_ok`;
CREATE PROCEDURE assert_sql_ok(IN stmt CHAR(64), IN msg CHAR(255))
	LANGUAGE SQL
	COMMENT 'Assert that stmt doesnt cause error/warning'
BEGIN
	DECLARE EXIT HANDLER
		FOR SQLWARNING, SQLEXCEPTION
	BEGIN
		-- error; trigger fail
		IF msg IS NULL THEN
			-- don want extra quotes here
			SET msg = CONCAT('SQL fails: ', IFNULL(stmt, ''));
		END IF;
		CALL `stk_unit`.assert(FALSE, msg);
	END;
	
	-- if it's a SELECT ..., turn it into a DO (SELECT ...);
	IF TRIM(stmt) LIKE 'SELECT %' THEN
		SET stmt = CONCAT(stmt);
		IF TRIM(stmt) LIKE '%;' THEN
			-- remove the ;
			SET stmt = CONCAT('DO (', TRIM(TRAILING ';' FROM TRIM(stmt)), ');');
		ELSE
			SET stmt = CONCAT('DO (', stmt, ');');
		END IF;
	END IF;
	
	-- execute query
	SET @__stk_u_stmt = stmt;
	PREPARE __stk_u_stmt_assert FROM @__stk_u_stmt;
	SET @__stk_u_stmt = NULL;
	EXECUTE __stk_u_stmt_assert;
	DEALLOCATE PREPARE __stk_u_stmt_assert;
	
	-- if execution comes here, SQL it's ok
	CALL `stk_unit`.assert(TRUE, msg);
END;


-- Pre-defined TS's
-- prefix: '_'


DROP PROCEDURE IF EXISTS `stk_suite`.`_all`;
CREATE PROCEDURE `stk_suite`._all()
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Run all TCs'
BEGIN
	-- end of results
	DECLARE eof BOOL;
	-- invidivual TCs name
	DECLARE tc_name CHAR(64);
	
	-- get all TCs
	DECLARE `__stk_u_crs_all_tc` CURSOR FOR
		SELECT `TEST_CASE_NAME`
			FROM `stk_unit`.`TEST_CASE`;
	
	-- handle eof
	DECLARE CONTINUE HANDLER
		FOR NOT FOUND
		SET eof = TRUE;
	
	-- loop on TCs
	OPEN `__stk_u_crs_all_tc`;
	`__stk_u_all_tc`: LOOP
		FETCH `__stk_u_crs_all_tc` INTO tc_name;
		
		-- end?
		IF eof = TRUE THEN
			LEAVE `__stk_u_all_tc`;
		END IF;
		
		-- run found TC
		CALL `stk_unit`.`test_case_run`(tc_name);
	END LOOP;
	CLOSE `__stk_u_crs_all_tc`;
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


##end

||
DELIMITER ;
