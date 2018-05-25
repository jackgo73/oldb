"""
Platform independent control of Oracle databases.
"""

import cx_ClassLibrary
import cx_IniFile
import cx_Logging
import cx_Utils
import os
import sys

if sys.platform == "win32":
    import cx_Win32Service

import Database
import Exceptions

GENERAL_SECTION = "general"
ENV_NAME = "CX_ORACLEDBATOOLS_ENV_SET"

class DatabaseType(object):

    def __init__(self, iniFile, section, configDir):

        # First set the required attributes on myself
        requiredKeys = ["oracleHome", "templateInitOra", "templateDirs",
                "templateCreate"]
        for key in requiredKeys:
            value = iniFile.GetValue(section, key)
            setattr(self, key, os.path.join(configDir, value))

        # Now for all the keys (except oracleHome) that are not a required
        # attribute, put them in a CaselessDict
        skipKeys = [a.lower() for a in requiredKeys[1:]]
        self.substitutions = cx_ClassLibrary.CaselessDict()
        for key in iniFile.GetSection(section).keys:
            if not key.name.lower() in skipKeys:
                self.substitutions[key.name] = key.value


class Manager(object):

    def __init__(self, fileName):
        iniFile = cx_IniFile.IniFile()
        iniFile.Read(fileName)
        self.configDir = os.path.dirname(fileName)
        self.baseDir = iniFile.GetValue(GENERAL_SECTION, "BaseDir")
        self.adminDir = os.path.join(self.baseDir, "admin")
        self.databaseTypes = cx_ClassLibrary.CaselessDict()
        for sectionObj in iniFile.sections:
            section = sectionObj.name.lower()
            if section != GENERAL_SECTION:
                self.databaseTypes[section] = \
                        DatabaseType(iniFile, section, self.configDir)
        defaultDatabaseType = iniFile.GetValue(GENERAL_SECTION, "DefaultType")
        if defaultDatabaseType not in self.databaseTypes:
            raise Exceptions.MissingDefaultDatabaseType()
        self.defaultDatabaseType = self.databaseTypes[defaultDatabaseType]
        if sys.platform == "win32":
            self.serviceManager = cx_Win32Service.ServiceManager()
        else:
            self.serviceManager = None

    def __EnvironmentConfig(self, sid):
        return os.path.join(self.adminDir, sid, "config", "env.cfg")

    def AllSids(self):
        if self.serviceManager is not None:
            startsWith = "OracleService"
            serviceNames = self.serviceManager.GetServiceNames(startsWith)
            return [n[len(startsWith):] for n in serviceNames]
        sids = []
        for name in os.listdir(self.adminDir):
            fileName = self.__EnvironmentConfig(name)
            if os.path.exists(fileName):
                sids.append(name)
        return sids

    def DatabaseBySid(self, sid, ignoreIfMissing = False):
        if self.serviceManager is not None:
            database = Database.Database(self, sid)
            if database.service is not None:
                binPath = database.service.binaryPathName.split()[0]
                database.oracleHome = os.path.dirname(os.path.dirname(binPath))
                if database.service.manual:
                    database.startMode = "Manual"
                else:
                    database.startMode = "Auto"
                return database
        else:
            fileName = self.__EnvironmentConfig(sid)
            if not ignoreIfMissing or os.path.exists(fileName):
                cx_Logging.Info("Reading environment from %s", fileName)
                iniFile = cx_IniFile.IniFile()
                iniFile.Read(fileName)
                oracleHome = iniFile.GetValue("Environment", "OracleHome")
                startMode = iniFile.GetValue("Environment", "StartMode")
                return Database.Database(self, sid, oracleHome, startMode)

    def DatabaseFromEnvironment(self, sysPassword, tnsentry):
        if ENV_NAME in os.environ:
            sid = os.environ["ORACLE_SID"]
            oracleHome = os.environ["ORACLE_HOME"]
            startMode = os.environ["START_MODE"]
            return Database.Database(self, sid, oracleHome, startMode,
                    sysPassword, tnsentry)

    def DatabaseTypeByName(self, name):
        if name is None:
            return self.defaultDatabaseType
        if name not in self.databaseTypes:
            raise Exceptions.MissingDatabaseType(typeName = name)
        return self.databaseTypes[name]

    def ExecuteForDatabase(self, database):
        cx_Logging.Debug("executing program for database %s", database)
        database.SetEnvironment()
        os.environ[ENV_NAME] = "Y"
        os.environ["START_MODE"] = database.startMode
        if sys.platform == "win32":
            executable = '"%s"' % sys.executable
        else:
            executable = sys.executable
        returnCode = os.spawnv(os.P_WAIT, sys.executable,
                [executable] + sys.argv[1:])
        if returnCode != 0:
            sys.exit(1)

