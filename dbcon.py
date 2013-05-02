'''
    STK-Unit Command line tool
    Copyright (C) 2013  Giacomo Picchiarelli

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
'''
from subprocess import Popen, PIPE
import MySQLdb
import sys
import gc


class dbconManager(object):
    MULTI_STATEMENTS_ON = 0
    MULTI_STATEMENTS_OFF = 1

    def __init__(self, host, db, user, pwd, port):
        self.host = host
        self.db = db
        self.user = user
        self.pwd = pwd
        self.port = port
        self._exc_error = " [dbconManager] "

    def openConnection(self):
        try:
            self.inner_conn = MySQLdb.connect(host=self.host, port=self.port,
                                              user=self.user, passwd=self.pwd,
                                              db=self.db)
            self.inner_conn.set_server_option(self.MULTI_STATEMENTS_ON)
        except:
            print self._exc_error + " -- Unexpected error:", sys.exc_info()[1]
            raise

    def executeFile(self, filename):
        print (filename)
        process = Popen('mysql %s -u%s -p%s' % (self.db, self.user, self.pwd),
                        stdout=PIPE, stdin=PIPE, shell=True)
        output = process.communicate('source ' + filename)[0]
        return output

    def executeMultipleStatement(self, sql):
        try:
            self.inner_conn.set_server_option(self.MULTI_STATEMENTS_ON)
            cursor = self.inner_conn.cursor()
            cursor.executemany(sql)
            cursor.commit()
            cursor.close()
            self.inner_conn.set_server_option(self.MULTI_STATEMENTS_OFF)
        except:
            self.inner_conn.rollback()
            print self._exc_error + "Unexpected error:", sys.exc_info()[0]
            raise

    def executeStatement(self, sql):
        try:
            cursor = self.inner_conn.cursor()
            cursor.execute(sql)
            res = cursor.fetchone()
            self.inner_conn.commit()
            self.inner_cursor.close()
            return res
        except:
            self.inner_conn.rollback()
            print self._exc_error + "Unexpected error:", sys.exc_info()[0]
            raise

    def closeConnection(self):
        try:
            self.inner_conn.close()
            #avoid some connection issues
            gc.collect()
        except:
            print self._exc_error + "Unexpected error:", sys.exc_info()[0]
            raise
