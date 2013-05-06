#! /usr/bin/env python2

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

import cmd
import conFile
import dbcon
import socket
from datetime import datetime


class stkc(cmd.Cmd):
    prompt = '> stkc@' + socket.gethostname() + '$ '
    intro = """
    stkc - STK-Unit Command line tool
    Copyright (C) 2013
    Giacomo Picchiarelli <gpicchiarelli@gmail.com>
    Federico Razzoli <santec@riseup.net>
    https://launchpad.net/~stk-unit-team
    """

    def do_upgrade(self, arg):
        'Upgrade STK for connection selected before.'
        self.cf = conFile.conFile()
        print(("upgraded " + arg))

    def do_install(self, arg):
        'Install STK for connection selected before.'
        try:
            op = self.database.executeFile('stk-unit/sql/stk_unit.sql')
            print("STK Installed")
            print (op)
        except AttributeError as e1:
            print(e1)
        except Exception as e:
            print(e)

    def do_sql(self, arg):
        'Execute sql statement'
        try:
            a = datetime.now()
            res = self.database.executeStatement(arg)
            b = datetime.now()
            c = b - a
            for itt in res:
                print(itt)
            tt = float(c.microseconds / 1000.0)
            print(' ------------------ ')
            print(('Done. ' + str(tt) + '(ms)'))
        except Exception as e:
            print(e)

    def do_executeUnit(self, arg):
        'Execute .sql file located in units'
        try:
            self.database.executeFile('units/' + arg)
            print(arg)
            print ("Executed")
        except Exception as e:
            print(e)

    def do_list(self, arg):
        'list available connections'
        self.cf = conFile.conFile()
        print((self.cf.listConnections()))

    def do_add(self, arg):
        'Add a new connection in settings'
        self.cf = conFile.conFile()
        print(("connection added " + arg))

    def do_open(self, arg):
        'Open DB Connection'
        try:
            cf = conFile.conFile()
            cf.setUpConnectionRegistry(arg)
            dd_db = dbcon.dbconManager(cf.host, cf.db, cf.user,
                                       cf.pwd, cf.port)
            dd_db.openConnection()
            self.database = dd_db
            self.cf = cf
            print("Connection OK.")
        except Exception as e:
            print(e)

    def do_close(self, arg):
        'Close active connection'
        try:
            self.database.closeConnection()
            print(("Connection closed [" + self.cf.name + "]"))
            self.cf = None
        except Exception as e:
            print(e)

    def do_delConn(self, arg):
        'Delete Connection'
        self.cf = conFile.conFile()
        self.cf.removeConnection(arg)

    def do_exit(self, arg):
        'Exit program.'
        print('Thank you. Bye.')
        exit()


def parse(arg):
    try:
        return tuple(map(int, arg.split()))
    except Exception as e:
        print(e)

if __name__ == "__main__":
    try:
        stkc().cmdloop()
    except KeyboardInterrupt as e:
        print("Forced quit")
