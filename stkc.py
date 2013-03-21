#! /usr/bin/python

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

import argparse
import conFile
import dbcon
import connWizard

class stkc(object):

    def hProg(self):
            print("")
            print("STK-Unit Command line tool")
            print("Copyright (C) 2013")
            print("Giacomo Picchiarelli <gpicchiarelli@gmail.com>")
            print("Federico Razzoli <santec@riseup.net>")
            print("")

    def addConnection(self,name):
        print("connection added " + name)

    def openConnection(self,name):
        cf = conFile.conFile()
        cf.setUpConnectionRegistry(name)
        dd_db = dbcon.dbconManager(cf.host,cf.db,cf.user,cf.pwd)
        dd_db.openConnection();

    def deleteConnection(self,name):
        print("connection del " + name  )


    def __init__(self):

        parser = argparse.ArgumentParser()
        parser.add_argument("-ca","--conadd", help="Add a new connection")
        parser.add_argument("-co","--conopen", help="Open selected connection")
        parser.add_argument("-cd","--condel", help="Delete selected connection")
        parser.add_argument("-cl","--conlist", help="List all connections", action='store_true')

        args = parser.parse_args()

        if args.conadd:
            self.addConnection(args.conadd)
        if args.condel:
            self.deleteConnection(args.condel)
        if args.conopen:
            self.openConnection(args.conopen)

if __name__ == "__main__":
    I1 = stkc()



