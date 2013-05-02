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
	test_lint is a Test Case for STK/Unit.
	Checks for bad practices and potential design mistakes in all existing
	databases.
	Asserts are generally based on commonly accepted best practices and advices
	found in MariaDB KnowledgeBase, in Percona's blogs or in MySQL documentation.
	But we all know that the Real World complexity sometimes doesn't suite well
	with the commonly accepted best practices or the hint we can find on the best
	sites around. So, even if test_lint triggers many fail on your server,
	your databases could be perfect for your own needs.
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
DROP DATABASE IF EXISTS `test_lint`;
CREATE DATABASE `test_lint`;
USE `test_lint`;


/*
 *	Table Index
 */


-- Test Primary Keys
CREATE PROCEDURE test_primary_key()
	LANGUAGE SQL
	COMMENT 'Test Primary Key'
BEGIN
	-- end for `crs_tabs`
	DECLARE `eof` BOOLEAN  DEFAULT FALSE;
	-- table/key info
	DECLARE `tab_name` TEXT DEFAULT NULL;
	-- check that PK exists
	DECLARE `num_keys` SMALLINT UNSIGNED DEFAULT NULL;
	
	-- TODO: compute key length
	DECLARE `crs_test` CURSOR FOR
		SELECT
				CONCAT('`', `t`.`TABLE_SCHEMA`, '`.`', `t`.`TABLE_NAME`, '`'),
				COUNT(`k`.`TABLE_NAME`)
			FROM `information_schema`.`TABLES` `t`
			LEFT JOIN `information_schema`.`KEY_COLUMN_USAGE` `k`
				ON `t`.`TABLE_NAME` = `k`.`TABLE_NAME`
			WHERE `k`.`CONSTRAINT_NAME` = 'PRIMARY' OR `k`.`CONSTRAINT_NAME` IS NULL
				-- exclude system & test dbs
				AND `t`.`TABLE_SCHEMA` NOT IN ('mysql', 'performance_schema', 'test')
				-- exclude views
				AND `t`.`TABLE_TYPE` = 'BASE TABLE'
			GROUP BY `t`.`TABLE_SCHEMA`, `t`.`TABLE_NAME`;
	
	DECLARE CONTINUE HANDLER
		FOR NOT FOUND
		SET `eof` = TRUE;
	
	OPEN `crs_test`;
	`lp_test`:
	LOOP
		FETCH NEXT FROM `crs_test`
			INTO `tab_name`, `num_keys`;
		
		IF `eof` IS TRUE THEN
			LEAVE `lp_test`;
		END IF;
		
		CALL `stk_unit`.assert_true(
				`num_keys` > 0,
				CONCAT('Warning: table ', `tab_name`, ' has not a Primary Key')
			);
	END LOOP;
	CLOSE `crs_test`;
END;


-- Test FK: parent & child table should be in the same db
CREATE PROCEDURE test_crossdb_foreign_key()
	LANGUAGE SQL
	COMMENT 'Test cross-DB Foreign Keys'
BEGIN
	-- end for `crs_tabs`
	DECLARE `eof` BOOLEAN  DEFAULT FALSE;
	-- constraint name
	DECLARE `constraint_id`  TEXT DEFAULT NULL;
	-- FK table
	DECLARE `origin`         TEXT DEFAULT NULL;
	-- referenced table
	DECLARE `referenced`     TEXT DEFAULT NULL;
	
	DECLARE `crs_test` CURSOR FOR
		SELECT
				DISTINCT(CONCAT('`', `TABLE_SCHEMA`, '`.`', `CONSTRAINT_NAME`, '`')),
				CONCAT('`', `TABLE_SCHEMA`, '`.`', `TABLE_NAME`, '`'),
				CONCAT('`', `REFERENCED_TABLE_SCHEMA`, '`.`', `REFERENCED_TABLE_NAME`, '`')
			FROM `information_schema`.`KEY_COLUMN_USAGE`
			WHERE
				`REFERENCED_TABLE_SCHEMA` IS NOT NULL
				AND `REFERENCED_TABLE_SCHEMA` <> `TABLE_SCHEMA`;
	
	DECLARE CONTINUE HANDLER
		FOR NOT FOUND
		SET `eof` = TRUE;
	
	OPEN `crs_test`;
	`lp_test`:
	LOOP
		FETCH NEXT FROM `crs_test`
			INTO `constraint_id`, `origin`, `referenced`;
		
		IF `eof` IS TRUE THEN
			LEAVE `lp_test`;
		END IF;
		
		CALL `stk_unit`.assert_true(
				FALSE,
				CONCAT('Warning: Foreign Key ', `constraint_id`, ' is cross-DB, from ', `origin`, ' to ', `referenced`)
			);
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
SET /*!50200 @@session.innodb_strict_mode = @__stk_u_old_innodb_strict_mode, */ @__stk_u_tmp = NULL;
SET /*!50200 @__stk_u_old_innodb_strict_mode = NULL, */ @__stk_u_tmp = NULL;


||
DELIMITER ;
