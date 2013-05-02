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
DROP DATABASE IF EXISTS `test_stk_unit_assertions`;
CREATE DATABASE `test_stk_unit_assertions`;
USE `test_stk_unit_assertions`;



/*
 *	Insert Test Data
 *	================
 */



/*
	Triggers cannot be created within a Stored Routine.
	That's why we need a unused non-MEMORY table: t1.
*/

DROP TABLE IF EXISTS `test_stk_unit_assertions`.`t1`;
	CREATE TABLE `test_stk_unit_assertions`.`t1` (
		`a` TINYINT UNSIGNED NOT NULL
	)
		ENGINE   = 'MyISAM';

CREATE TRIGGER `test_stk_unit_assertions`.`my_trig`
		BEFORE INSERT
		ON `t1`
		FOR EACH ROW
	BEGIN
		SET @val = NULL;
	END;

CREATE PROCEDURE `test_stk_unit_assertions`.`my_proc`()
	COMMENT 'Test data'
BEGIN
	SET @val = NULL;
END;

CREATE FUNCTION `test_stk_unit_assertions`.`my_func`()
	RETURNS TINYINT
	DETERMINISTIC
	NO SQL
	COMMENT 'Test data'
BEGIN
	RETURN 1;
END;

-- we should exlude this from 5.0, but using exec comments here throws error
CREATE EVENT `test_stk_unit_assertions`.`my_event`
	ON SCHEDULE AT CURRENT_TIMESTAMP + INTERVAL 10 YEAR
	ON COMPLETION PRESERVE
	DISABLE
	COMMENT 'Test data'
	DO SET @val = NULL;



CREATE PROCEDURE before_all_tests()
	LANGUAGE SQL
	COMMENT 'DDL for test stuff'
BEGIN
	-- we can create some objects from within a Stored Routine.
	-- while the DB should never be touched,
	-- this practice should be a bit safer.
	
	DROP TABLE IF EXISTS `test_stk_unit_assertions`.`my_tab`;
	CREATE TABLE `test_stk_unit_assertions`.`my_tab` (
		`a`  TINYINT NULL,
		`b`  CHAR(1) NULL
	)
		ENGINE   = 'MEMORY',
		DEFAULT CHARACTER SET = ascii,
		COLLATE = ascii_bin,
		COMMENT = 'Test data';
	
	INSERT INTO `test_stk_unit_assertions`.`my_tab` (`a`, `b`)
		VALUES
			(1, ''),
			(2, NULL);
	
	DROP TABLE IF EXISTS `test_stk_unit_assertions`.`empty_tab`;
	CREATE TABLE `test_stk_unit_assertions`.`empty_tab` (
		`a`  TINYINT NULL,
		`b`  CHAR(1) NULL
	)
		ENGINE   = 'MEMORY',
		DEFAULT CHARACTER SET = ascii,
		COLLATE = ascii_bin,
		COMMENT = 'Test data';
	
	DROP TABLE IF EXISTS `test_stk_unit_assertions`.`ya_tab`;
	CREATE TABLE `test_stk_unit_assertions`.`ya_tab` (
		`a`  TINYINT NULL
	)
		ENGINE   = 'MEMORY',
		COMMENT  = 'Test data';
	
	INSERT INTO `test_stk_unit_assertions`.`ya_tab` (`a`)
		VALUES (10), (20), (30);
	
	CREATE OR REPLACE VIEW `test_stk_unit_assertions`.`my_view` AS
		SELECT * FROM `my_tab`;
END;


/*
 *	Insert Tests
 *	============
 */


-- event if CREATEs are commented, DROP for documentation purposes
DROP PROCEDURE IF EXISTS `test_fail_1`;
DROP PROCEDURE IF EXISTS `test_fail_2`;
DROP PROCEDURE IF EXISTS `test_exception_1`;

/*
	# Uncomment this to get some fails
	
	# These BTs should add:
	# 1 Pass
	# 2 Fail
	# 1 Exception
	
	CREATE PROCEDURE test_fail_1()
		LANGUAGE SQL
		COMMENT 'artificial fail 1'
	BEGIN
		CALL `stk_unit`.assert(FALSE, 'This is an assert that should FAIL');
	END;

	CREATE PROCEDURE test_fail_2()
		LANGUAGE SQL
		COMMENT 'artificial fail 2'
	BEGIN
		CALL `stk_unit`.assert(TRUE, 'This should PASS');
		CALL `stk_unit`.assert(FALSE, 'Second assert of this BT should FAIL');
	END;
	
	CREATE PROCEDURE test_exception_1()
		LANGUAGE SQL
		COMMENT 'artificial exception 1'
	BEGIN
		SIGNAL SQLSTATE VALUE '45000';
	END;
*/

CREATE PROCEDURE test_assert()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert() works'
BEGIN
	CALL `stk_unit`.assert(TRUE, 'ERR: This should pass!!');
	CALL `stk_unit`.assert('1', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_ignore_all_exceptions()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.ignore_all_exceptions() works'
BEGIN
	CALL `stk_unit`.ignore_all_exceptions();
	CALL `stk_unit`.assert_true(TRUE, 'ERR: This should pass!!');
	CREATE DATABASE `mysql`;
	CALL `stk_unit`.assert_true(FALSE, 'ERR: This should not be tested!!');
END;

CREATE PROCEDURE test_expect_any_exception()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.expect_any_exception() works'
BEGIN
	CALL `stk_unit`.expect_any_exception();
	CALL `stk_unit`.assert_true(TRUE, 'ERR: This should pass!!');
	CREATE DATABASE `mysql`;
	CALL `stk_unit`.assert_true(FALSE, 'ERR: This should not be tested!!');
END;

CREATE PROCEDURE test_assert_true()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_true() works'
BEGIN
	CALL `stk_unit`.assert_true(TRUE, 'ERR: This should pass!!');
	CALL `stk_unit`.assert_true('1', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_false()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.test_assert_false() works'
BEGIN
	CALL `stk_unit`.assert_false(FALSE, 'ERR: This should pass!!');
	CALL `stk_unit`.assert_false('0', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_false('', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_null()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_null() works'
BEGIN
	CALL `stk_unit`.assert_null(NULL, 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_not_null()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_not_null() works'
BEGIN
	CALL `stk_unit`.assert_not_null('', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_equals()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_equals() works'
BEGIN
	CALL `stk_unit`.assert_equals('abc', 'abc', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_equals(1, 1, 'ERR: This should pass!!');
	CALL `stk_unit`.assert_equals('123', 123, 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_not_equals()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_not_equals() works'
BEGIN
	CALL `stk_unit`.assert_not_equals('a', 'b', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_not_equals(1, -1, 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_like()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_like() works'
BEGIN
	CALL `stk_unit`.assert_like('emiliano zapata', 'emiliano%', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_like('carlos santana', '%sa_tana', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_not_like()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_not_like() works'
BEGIN
	CALL `stk_unit`.assert_not_like('carlos santana', '%hey%', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_like_with_escape()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_like_with_escape() works'
BEGIN
	CALL `stk_unit`.assert_like_with_escape('Erik_', 'Erik|_', '|', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_not_like_with_escape()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_not_like_with_escape() works'
BEGIN
	CALL `stk_unit`.assert_not_like_with_escape('Erik!', 'Erik|_', '|', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_regexp()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_regexp() works'
BEGIN
	CALL `stk_unit`.assert_regexp('MariaDB', 'DB', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_not_regexp()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_regexp() works'
BEGIN
	CALL `stk_unit`.assert_not_regexp('MariaDB', 'oracle', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_regexp_binary()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_regexp() works'
BEGIN
	CALL `stk_unit`.assert_regexp_binary('MariaDB', 'DB', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_not_regexp_binary()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_regexp() works'
BEGIN
	CALL `stk_unit`.assert_not_regexp_binary('MariaDB', 'db', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_database_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_database_exists() works'
BEGIN
	CALL `stk_unit`.assert_database_exists('test_stk_unit_assertions', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_database_not_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_database_not_exists() works'
BEGIN
	CALL `stk_unit`.assert_database_not_exists('no-exist', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_table_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_table_exists() works'
BEGIN
	CALL `stk_unit`.assert_table_exists('test_stk_unit_assertions', 'my_tab', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_table_not_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_table_not_exists() works'
BEGIN
	CALL `stk_unit`.assert_table_not_exists('test_stk_unit_assertions', 'not_exists', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_table_not_exists('not_exists', 'my_table', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_view_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_view_exists() works'
BEGIN
	CALL `stk_unit`.assert_view_exists('test_stk_unit_assertions', 'my_view', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_view_not_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_view_not_exists() works'
BEGIN
	CALL `stk_unit`.assert_view_not_exists('test_stk_unit_assertions', 'not_exists', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_view_not_exists('not_exists', 'my_view', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_routine_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_routine_exists() works'
BEGIN
	CALL `stk_unit`.assert_routine_exists('test_stk_unit_assertions', 'my_func', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_routine_exists('test_stk_unit_assertions', 'my_proc', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_routine_not_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_routine_not_exists() works'
BEGIN
	CALL `stk_unit`.assert_routine_not_exists('test_stk_unit_assertions', 'not_exists', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_routine_not_exists('not_exists', 'my_proc', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_event_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_event_exists() works'
BEGIN
	CALL `stk_unit`.assert_event_exists('test_stk_unit_assertions', 'my_event', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_event_not_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_event_not_exists() works'
BEGIN
	CALL `stk_unit`.assert_event_not_exists('test_stk_unit_assertions', 'not_exists', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_event_not_exists('not_exists', 'my_event', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_trigger_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_trigger_exists() works'
BEGIN
	CALL `stk_unit`.assert_trigger_exists('test_stk_unit_assertions', 'my_trig', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_trigger_not_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_trigger_not_exists() works'
BEGIN
	CALL `stk_unit`.assert_trigger_not_exists('test_stk_unit_assertions', 'not_exists', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_trigger_not_exists('not_exists', 'my_trig', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_column_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_column_exists() works'
BEGIN
	CALL `stk_unit`.assert_column_exists('test_stk_unit_assertions', 'my_tab', 'a', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_column_not_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_column_not_exists() works'
BEGIN
	CALL `stk_unit`.assert_column_not_exists('not_exists', 'my_tab', 'a', 'this db not exists');
	CALL `stk_unit`.assert_column_not_exists('test_stk_unit_assertions', 'not_exists', 'a', 'this table not exists');
	CALL `stk_unit`.assert_column_not_exists('test_stk_unit_assertions', 'my_tab', 'not_exists', 'this col not exists');
END;

CREATE PROCEDURE test_assert_row_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_row_exists() works'
BEGIN
	CALL `stk_unit`.assert_row_exists('test_stk_unit_assertions', 'my_tab', 'a', 1, 'ERR: This should pass!!');
	CALL `stk_unit`.assert_row_exists('test_stk_unit_assertions', 'my_tab', 'b', NULL, 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_row_not_exists()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_row_not_exists() works'
BEGIN
	CALL `stk_unit`.assert_row_not_exists('test_stk_unit_assertions', 'my_tab', 'a', 100, 'ERR: This should pass!!');
	CALL `stk_unit`.assert_row_not_exists('test_stk_unit_assertions', 'my_tab', 'a', NULL, 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_rows_count()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_rows_count() works'
BEGIN
	CALL `stk_unit`.assert_rows_count('test_stk_unit_assertions', 'my_tab', 2, 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_table_empty()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_table_empty() works'
BEGIN
	CALL `stk_unit`.assert_table_empty('test_stk_unit_assertions', 'empty_tab', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_table_not_empty()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_table_not_empty() works'
BEGIN
	CALL `stk_unit`.assert_table_not_empty('test_stk_unit_assertions', 'my_tab', 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_field_count_distinct()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_field_count_distinct() works'
BEGIN
	CALL `stk_unit`.assert_field_count_distinct('test_stk_unit_assertions', 'my_tab', 'a', 2, 'ERR: This should pass!!');
	CALL `stk_unit`.assert_field_count_distinct('test_stk_unit_assertions', 'my_tab', 'b', 1, 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_field_min()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_field_min() works'
BEGIN
	CALL `stk_unit`.assert_field_min('test_stk_unit_assertions', 'ya_tab', 'a', 10, 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_field_avg()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_field_avg() works'
BEGIN
	CALL `stk_unit`.assert_field_avg('test_stk_unit_assertions', 'ya_tab', 'a', 20, 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_field_max()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_field_max() works'
BEGIN
	CALL `stk_unit`.assert_field_max('test_stk_unit_assertions', 'ya_tab', 'a', 30, 'ERR: This should pass!!');
END;

CREATE PROCEDURE test_assert_sql_ok()
	LANGUAGE SQL
	COMMENT 'Test that stk_unit.assert_sql_ok() works'
BEGIN
	-- check that SELECT transformations to avoid the SELECT results
	-- are always correct
	CALL `stk_unit`.assert_sql_ok('SELECT 1',  'ERR: This should pass!!');
	CALL `stk_unit`.assert_sql_ok('SELECT 1;', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_sql_ok('Select 1;', 'ERR: This should pass!!');
	CALL `stk_unit`.assert_sql_ok('DO (SELECT 1);', 'ERR: This should pass!!');
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
