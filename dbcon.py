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

import MySQLdb
import sys
import gc

## self.inner_conn is internal object for mysql/mariadb connection

class dbconManager(object):
    
    def __init__(self,host,db,user,pwd):
        self.host = host
        self.db = db
        self.user = user
        self.pwd = pwd
        self._exc_error = " [dbconManager] "
        
    def openConnection(self):
        try:
            self.inner_conn = MySQLdb.connect(host=self.host,user=self.user,passwd=self.pwd,db=self.db)
        except:
            print self._exc_error + "Unexpected error:", sys.exc_info()[0]
            raise
    
    def executeStatement(self,sql):
        try:
            cursor = self.inner_conn.cursor()
            cursor.execute(sql)
            self.inner_conn.commit()
        except:
            self.inner_conn.rollback()
            print self._exc_error + "Unexpected error:", sys.exc_info()[0]
            raise

    def closeConnection(self):
        try:
            self.inner_conn.close()
            gc.collect() #avoid some connection issues
        except:
            print self._exc_error + "Unexpected error:", sys.exc_info()[0]
            raise
        
