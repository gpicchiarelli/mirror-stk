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

# RFC #733  Compliant

try:
    import configparser
except ImportError:
    import ConfigParser as configparser


class conFile(object):

    def __init__(self):
        config = configparser.ConfigParser()
        config.readfp(open('stkc.cfg'))
        self.config = config

    def listConnections(self):
        listal = self.config.sections()
        return listal[0:len(listal) - 1]

    def setUpConnectionRegistry(self, name_connection):
        self.name = self.config.get(name_connection, 'NAME')
        self.host = self.config.get(name_connection, 'HOST')
        self.user = self.config.get(name_connection, 'USER')
        self.pwd = self.config.get(name_connection, 'PWD')
        self.db = self.config.get(name_connection, 'DB')
        try:
            self.port = int(self.config.get(name_connection, 'PORT'))
        except Exception as e:
            print(e)

    def removeConnection(self, connection):
        if (connection.strip() != 'ALIAS'):
            self.config.remove_section(connection)
