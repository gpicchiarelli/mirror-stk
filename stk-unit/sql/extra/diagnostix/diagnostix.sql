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
	diagnostix is a Test Suite for STK/Unit which runs some diagnostic Test Cases.
	These TCs are Unit Tests, but do something totally different from what
	Unit Tests usually do, because they check server settings and databases
	structure. In some circumstances they could be of some help for DBAs and
	developers. But, most probably, they show how to use STK/Unit for special
	purposes, and serve as examples to create new Test Cases.
	For further details, you can check the individual Test Cases.
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


DROP PROCEDURE IF EXISTS `stk_suite`.`diagnostix`;
CREATE PROCEDURE `stk_suite`.`diagnostix`()
	MODIFIES SQL DATA
	LANGUAGE SQL
	COMMENT 'Diagnostic TCs (examples for STK/Unit))'
BEGIN
	CALL `stk_unit`.`test_case_run`('test_checkup');
	CALL `stk_unit`.`test_case_run`('test_lint');
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
