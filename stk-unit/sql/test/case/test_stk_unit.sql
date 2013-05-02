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
DROP DATABASE IF EXISTS `test_stk_unit`;
CREATE DATABASE `test_stk_unit`;
USE `test_stk_unit`;


CREATE TABLE `run_routine`
(
	`name` CHAR(50) NOT NULL
)
	ENGINE   = 'MEMORY',
	DEFAULT CHARACTER SET = ascii,
	COLLATE = ascii_bin,
	COMMENT = 'Test data';



CREATE PROCEDURE before_all_tests()
	LANGUAGE SQL
	COMMENT 'Test that before_all_tests() is called'
BEGIN
	TRUNCATE TABLE `run_routine`;
	INSERT HIGH_PRIORITY INTO `run_routine` (`name`) VALUES ('before_all_tests');
END;

CREATE PROCEDURE set_up()
	LANGUAGE SQL
	COMMENT 'Test that set_up() is called'
BEGIN
	INSERT HIGH_PRIORITY INTO `run_routine` (`name`) VALUES ('set_up');
END;

CREATE PROCEDURE tear_down()
	LANGUAGE SQL
	COMMENT 'Test that tear_down() is called'
BEGIN
	INSERT HIGH_PRIORITY INTO `run_routine` (`name`) VALUES ('tear_down');
END;

CREATE PROCEDURE after_all_tests()
	LANGUAGE SQL
	COMMENT 'Test that after_all_tests() is called'
BEGIN
	INSERT HIGH_PRIORITY INTO `run_routine` (`name`) VALUES ('after_all_tests');
END;

CREATE PROCEDURE test_a()
	LANGUAGE SQL
	COMMENT 'First. Triggers setup & teardown'
BEGIN
	DO NULL;
END;

CREATE PROCEDURE test_setup_teardown()
	LANGUAGE SQL
	COMMENT 'Test set_up tear_down before/after_all_tests'
BEGIN
	CALL `stk_unit`.assert_true(
			(SELECT COUNT(*) > 0 FROM `run_routine` WHERE `name` = 'set_up'),
			'set_up() not executed'
		);
	CALL `stk_unit`.assert_true(
			(SELECT COUNT(*) > 0 FROM `run_routine` WHERE `name` = 'tear_down'),
			'tear_down() not executed'
		);
	CALL `stk_unit`.assert_true(
			(SELECT COUNT(*) > 0 FROM `run_routine` WHERE `name` = 'before_all_tests'),
			'before_all_tests() not executed'
		);
	/*
		How can we test this?
	CALL `stk_unit`.assert_true(
			(SELECT COUNT(*) > 0 FROM `run_routine` WHERE `name` = 'after_all_tests'),
			'after_all_tests() not executed'
		);
	*/
END;

CREATE PROCEDURE test_xml_replace()
	LANGUAGE SQL
	COMMENT 'Test xml_encode()'
BEGIN
	CALL `stk_unit`.`assert_equals`(stk_unit.xml_encode('abc'), 'abc', NULL);
	CALL `stk_unit`.`assert_equals`(stk_unit.xml_encode(''), '', NULL);
	CALL `stk_unit`.`assert_null`(stk_unit.xml_encode(NULL), NULL);
	
	CALL `stk_unit`.`assert_equals`(stk_unit.xml_encode('&<'), '&amp;&lt;', NULL);
	CALL `stk_unit`.`assert_equals`(stk_unit.xml_encode('&amp;&lt;'), '&amp;amp;&amp;lt;', NULL);
END;

CREATE PROCEDURE test_ns_str()
	LANGUAGE SQL
	COMMENT 'Test quote_name()'
BEGIN
	CALL `stk_unit`.`assert_equals`(stk_unit.ns_str("x"), "'x'", 'Incorrect quoting');
	CALL `stk_unit`.`assert_equals`(stk_unit.ns_str("x'y"), "'x\\'y'", 'Incorrect escape');
	
	CALL `stk_unit`.`assert_equals`(stk_unit.ns_str(""), "''", 'Empty quotes expected');
	CALL `stk_unit`.`assert_equals`(stk_unit.ns_str(NULL), "NULL", 'For NULL value, string "NULL" should be returned');
END;

CREATE PROCEDURE test_quote_name()
	LANGUAGE SQL
	COMMENT 'Test quote_name()'
BEGIN
	CALL `stk_unit`.`assert_equals`(stk_unit.quote_name('x'), '`x`', 'Incorrect quoting');
	CALL `stk_unit`.`assert_equals`(stk_unit.quote_name('x`y'), '`x``y`', 'Incorrect escape');
	
	CALL `stk_unit`.`assert_equals`(stk_unit.quote_name(''), '``', 'Empty name expected');
	CALL `stk_unit`.`assert_equals`(stk_unit.quote_name(NULL), '``', 'For NULL value, empty name should be returned');
END;

CREATE PROCEDURE test_config_set_get()
	LANGUAGE SQL
	COMMENT 'Test config_set(), config_get()'
BEGIN
	DECLARE `res` TEXT;
	DECLARE `val` TEXT;
	DECLARE `zero` CHAR(1) DEFAULT '0';
	DECLARE `unus` CHAR(1) DEFAULT '1';
	
	-- set & get valid option
	CALL `stk_unit`.`config_set`('show_err', `zero`);
	SET `res` = `stk_unit`.`config_get`('show_err');
	CALL `stk_unit`.`assert_equals`(`res`, `zero`,
		CONCAT('Incorrect option value; should be ', IFNULL(`zero`, 'NULL'), ', got: ', IFNULL(`res`, 'NULL')));
	
	-- change & read again same option
	CALL `stk_unit`.`config_set`('show_err', `unus`);
	SET `res` = `stk_unit`.`config_get`('show_err');
	CALL `stk_unit`.`assert_equals`(`res`, `unus`,
		CONCAT('Incorrect option value; should be ', IFNULL(`unus`, 'NULL'), ', got: ', IFNULL(`res`, 'NULL')));
END;

CREATE PROCEDURE test_config_set_invalid()
	LANGUAGE SQL
	COMMENT 'Test config_set()'
BEGIN
	-- try to set invalid option
	/*!50500
		CALL `stk_unit`.`expect_any_exception`();
	*/
	CALL `stk_unit`.`config_set`('not-exists', '1');
END;

CREATE PROCEDURE test_log_result()
	LANGUAGE SQL
	COMMENT 'Test log_result()'
BEGIN
	-- number of "artificial" test results
	DECLARE num_entries_art  BIGINT UNSIGNED     DEFAULT NULL;
	-- identifies an "artificial" test result, created by the test
	DECLARE test_note        CHAR(50)            DEFAULT 'Intentionally generated by the test';
	
	-- delete "artificial" results
	-- (yes, we have to do this before AND after)
	DELETE
		FROM `stk_unit`.`test_results`
		WHERE `msg` = test_note;
	
	-- insert "artificial" results
	CALL `stk_unit`.log_result('pass',       test_note);
	CALL `stk_unit`.log_result('fail',       test_note);
	CALL `stk_unit`.log_result('exception',  test_note);
	
	-- "artificial" results must be 3
	SELECT COUNT(*)
		FROM `stk_unit`.`test_results`
		WHERE `msg` = test_note
		INTO `num_entries_art`;
	CALL `stk_unit`.assert_true(num_entries_art = 3, CONCAT('Created entries: ', num_entries_art, ' instead of 3'));
	
	-- delete "artificial" results
	DELETE
		FROM `stk_unit`.`test_results`
		WHERE `msg` = test_note;
END;

CREATE PROCEDURE test_expect()
	LANGUAGE SQL
	COMMENT 'Test ignore_all_exceptions(), expect_any_exception()'
BEGIN
	DECLARE num_entries TINYINT UNSIGNED DEFAULT NULL;
	
	CALL `stk_unit`.ignore_all_exceptions();
	SELECT COUNT(*) FROM `stk_unit`.`expect` INTO num_entries;
	CALL `stk_unit`.assert_true(num_entries = 1, CONCAT('Created entries: ', num_entries, ' instead of 1'));
	
	CALL `stk_unit`.clean_expect();
	SELECT COUNT(*) FROM `stk_unit`.`expect` INTO num_entries;
	CALL `stk_unit`.assert_true(num_entries = 0, CONCAT('Expectations of type ignore not cleaned'));
	
	CALL `stk_unit`.expect_any_exception();
	SELECT COUNT(*) FROM `stk_unit`.`expect` INTO num_entries;
	CALL `stk_unit`.assert_true(num_entries = 1, CONCAT('Created entries: ', num_entries, ' instead of 1'));
	
	CALL `stk_unit`.clean_expect();
	SELECT COUNT(*) FROM `stk_unit`.`expect` INTO num_entries;
	CALL `stk_unit`.assert_true(num_entries = 0, CONCAT('Expectations of type expect not cleaned'));
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

