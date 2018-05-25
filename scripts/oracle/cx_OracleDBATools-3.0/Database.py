"""
Define classes for handling Oracle databases.
"""

import cx_ClassLibrary
import cx_Logging
import cx_ShellUtils
import cx_Utils
import imp
import os
import signal
import socket
import subprocess
import sys

import Exceptions
import DatabaseInfo
import Utils

if sys.platform == "win32":
    CONFIG_DIR = "Database"
else:
    CONFIG_DIR = "dbs"


class ActualParameterFileNameDescriptor(object):

    def __get__(self, database, databaseType):
        return os.path.join(database.adminDir, "pfile", "init.ora")


class BinDirDescriptor(object):

    def __get__(self, database, databaseType):
        return os.path.join(database.oracleHome, "bin")


class ConfigFileNameDescriptor(object):

    def __init__(self, baseName):
        self.baseName = baseName

    def __get__(self, database, databaseType):
        fileName = "%s.cfg" % self.baseName
        return os.path.join(database.adminDir, "config", fileName)


class ConnectionDescriptor(object):

    def __get__(self, database, databaseType):
        database.SetEnvironment()
        driver = database.driver
        return driver.Connection(database.connectString, mode = driver.SYSDBA)


class ConnectStringDescriptor(object):

    def __get__(self, database, databaseType):
        if database.sysPassword is None:
            return "/"
        connectString = "sys/%s" % database.sysPassword
        if database.tnsentry is not None:
            connectString = "%s@%s" % (connectString, database.tnsentry)
        return connectString


class ControlFilesDescriptor(object):

    def __get__(self, database, databaseType):
        rawControlFiles = database.info.parameters["control_files"]
        return [n.strip() for n in rawControlFiles.split(",")]


class DriverDescriptor(object):
    if sys.platform == "win32":
        filesToCheck = [
                ("11g", "oraclient11.dll"),
                ("10g", "oraclient10.dll")
        ]
    else:
        filesToCheck = [
                ("11g", "libclient11.a"),
                ("10g", "libclient10.a")
        ]

    def __get__(self, database, databaseType):
        for version, fileName in self.filesToCheck:
            if sys.platform == "win32":
                fileName = os.path.join(database.binDir, fileName)
            else:
                fileName = os.path.join(database.libDir, fileName)
            if os.path.exists(fileName):
                suffix, mode, moduleType = imp.get_suffixes()[0]
                executable = sys.executable
                while os.path.islink(executable):
                    dirName = os.path.dirname(executable)
                    executable = os.path.abspath(os.path.join(dirName,
                            os.readlink(executable)))
                dirName = os.path.dirname(executable)
                fileName = os.path.join(dirName,
                        "cx_Oracle_%s%s" % (version, suffix))
                try:
                    database.driver = imp.load_dynamic("cx_Oracle", fileName)
                except ImportError:
                    raise Exceptions.MissingOracleDriver(version = version)
                return database.driver
        raise Exceptions.MissingOracleInstallation()


class InfoDescriptor(object):

    def __get__(self, database, databaseType):
        info = DatabaseInfo.DatabaseInfo()
        info.PopulateFromDatabase(database)
        database.info = info
        return info


class LibDirDescriptor(object):

    def __get__(self, database, databaseType):
        libDir = os.path.join(database.oracleHome, "lib")
        path = os.path.join(database.oracleHome, "lib64")
        if os.path.exists(path):
            libDir = path
        return libDir


class OracleConfigFileNameDescriptor(object):

    def __init__(self, prefix):
        self.prefix = prefix

    def __get__(self, database, databaseType):
        fileName = "%s%s.ora" % (self.prefix, database.sid)
        return os.path.join(database.oracleHome, CONFIG_DIR, fileName)


class PasswordFileNameDescriptor(object):

    def __get__(self, database, databaseType):
        if sys.platform == "win32":
            fileName = "pwd%s.ora" % database.sid
        else:
            fileName = "orapw%s" % database.sid
        return os.path.join(database.oracleHome, CONFIG_DIR, fileName)


class ServiceDescriptor(object):

    def __get__(self, database, databaseType):
        if database.hasService:
            serviceName = "OracleService%s" % database.sid
            return database.manager.serviceManager.GetService(serviceName,
                    ignoreError = True)


class Database(object):
    parameterFileName = OracleConfigFileNameDescriptor("init")
    storedParameterFileName = OracleConfigFileNameDescriptor("spfile")
    passwordFileName = PasswordFileNameDescriptor()
    actualParameterFileName = ActualParameterFileNameDescriptor()
    diskConfigFileName = ConfigFileNameDescriptor("disk")
    envConfigFileName = ConfigFileNameDescriptor("env")
    connectString = ConnectStringDescriptor()
    controlFiles = ControlFilesDescriptor()
    connection = ConnectionDescriptor()
    service = ServiceDescriptor()
    driver = DriverDescriptor()
    binDir = BinDirDescriptor()
    libDir = LibDirDescriptor()
    info = InfoDescriptor()

    def __init__(self, manager, sid, oracleHome = None, startMode = "Manual",
            sysPassword = None, tnsentry = None):
        self.manager = manager
        self.sid = sid
        self.oracleHome = oracleHome
        self.adminDir = os.path.join(manager.adminDir, sid)
        self.startMode = startMode
        self.sysPassword = sysPassword
        self.tnsentry = tnsentry
        self.hasService = (manager.serviceManager is not None)
        if tnsentry is not None and sysPassword is None:
            self.sysPassword = socket.gethostname().split(".")[0]

    def __repr__(self):
        return "<%s %s (%s)>" % \
                (self.__class__.__name__, self.sid, self.oracleHome)

    def __CreateDirectory(self, dirName):
        if not os.path.isdir(dirName):
            os.makedirs(dirName)

    def __CreateFile(self, fileName):
        self.__CreateDirectory(os.path.dirname(fileName))
        return file(fileName, "w")

    def __PrependPathEnvVar(self, varName, value):
        origValue = os.environ.get(varName)
        if origValue is not None:
            if not origValue.startswith(value + os.pathsep):
                value = value + os.pathsep + origValue
        os.environ[varName] = value

    def __RunCommand(self, *args):
        if sys.platform != "win32":
            signal.signal(signal.SIGCLD, signal.SIG_DFL)
        exitCode = subprocess.call(args)
        if exitCode != 0:
            raise Exceptions.CommandFailed(command = " ".join(args),
                    exitCode = exitCode)

    def Clone(self, database, mapping, offline):
        self.info = database.info.Clone(self.sid, mapping)
        self.Initialize(dirs = self.GetDirectories())
        database.SetEnvironment()
        if not offline:
            database.info.PopulateRecoverStartSequence(database)
        session = Utils.RecoveryManagerSession()
        if offline:
            session.AddCommand("shutdown immediate")
            session.AddCommand("startup mount")
        copyObjects = []
        for dataFile in database.info.dataFiles:
            targetFileName = mapping.MappedFileName(dataFile.name)
            copyObjects.append("datafile '%s' to '%s'" % \
                    (dataFile.name, targetFileName))
        session.AddCommand("copy %s", ",\n".join(copyObjects))
        if offline:
            session.AddCommand("alter database open")
        database.RunRecoveryManagerSession("clone.rmn", session)
        if offline:
            archiveLogDir = None
        else:
            logs = database.info.PopulateRecoverChangeNumber(database)
            archiveLogDir = os.path.dirname(logs[0])
        recoverClause = database.info.GetRecoverClause(archiveLogDir)
        sql = self.info.ExportControlFile(recoverClause = recoverClause)
        self.RunInSqlplus("clone.sql", sql)

    def Create(self, databaseType, substitutions):
        args = cx_ClassLibrary.CaselessDict(SID = self.sid,
                BASE_DIR = self.manager.baseDir,
                ADMIN_DIR = self.adminDir,
                ORACLE_HOME = self.oracleHome,
                SYS_PW = self.sysPassword)
        for key in substitutions:
            if key not in args:
                args[key] = substitutions[key]
        for key in databaseType.substitutions:
            if key not in args:
                args[key] = databaseType.substitutions[key]
        parameters = file(databaseType.templateInitOra).read() % args
        createSql = file(databaseType.templateCreate).read() % args
        rawDirs = file(databaseType.templateDirs).read() % args
        dirs = [s.strip() for s in rawDirs.splitlines() if s.strip()]
        self.Initialize(parameters, dirs)
        self.RunInSqlplus("create.sql", createSql)
        self.Stop()

    def GetDirectories(self, includeDataFiles = True):
        dirs = self.info.GetDirectories(includeDataFiles)
        if self.adminDir not in dirs:
            dirs.insert(0, self.adminDir)
        return dirs

    def Initialize(self, parameters = None, dirs = None):
        self.WriteActualParameterFile(parameters)
        self.LinkParameterFile()
        self.WriteDiskConfigFile(dirs)
        self.WriteEnvironmentConfigFile()
        if self.hasService:
            oraDim = os.path.join(self.binDir, "oradim")
            command = "%s -NEW -SID %s -INTPWD %s -STARTMODE A"
            cx_Utils.ExecuteOSCommands(command % \
                    (oraDim, self.sid, self.sysPassword))

    def IsAvailable(self):
        if self.hasService and self.service.stopped:
            return False
        try:
            cursor = self.connection.cursor()
            return True
        except self.driver.DatabaseError as errorInfo:
            errorInfo, = errorInfo.args
            if errorInfo.code in (1034, 12500):    # Oracle not started up
                return False
            elif errorInfo.code == 1031: # insufficient privileges
                return True
            elif errorInfo.code in (1089, 1090):  # shutdown in progress
                return True
            raise

    def LinkParameterFile(self):
        parameterFileName = self.parameterFileName
        actualParameterFileName = self.actualParameterFileName
        dirName = os.path.dirname(actualParameterFileName)
        if sys.platform == "win32":
            syntax = "IFILE='%s'" % actualParameterFileName
            file(parameterFileName, "w").write(syntax)
        else:
            if os.path.exists(parameterFileName):
                os.remove(parameterFileName)
            os.symlink(actualParameterFileName, parameterFileName)

    def Remove(self):
        cx_Logging.Trace("Removing database...")
        self.Stop("abort")
        if self.service is not None:
            oraDim = os.path.join(self.binDir, "oradim")
            command = "%s -DELETE -SID %s" % (oraDim, self.sid)
            cx_Utils.ExecuteOSCommands(command)
        entries = [s.strip() for s in file(self.diskConfigFileName)]
        entries.append(self.adminDir)
        entries.append(self.parameterFileName)
        entries.append(self.storedParameterFileName)
        entries.append(self.passwordFileName)
        dirsToCheck = {}
        for entry in entries:
            if not os.path.exists(entry):
                continue
                dirsToCheck[os.path.dirname(entry)] = None
            cx_ShellUtils.Remove(entry)
        for dir in dirsToCheck:
            if not os.path.exists(dir):
                continue
            if not os.listdir(dir):
                cx_Logging.Trace("removing directory %s...", dir)
                os.rmdir(dir)
        cx_Logging.Trace("Database %s removed.", self.sid)

    def RemoveControlFiles(self):
        controlFiles = self.info.parameters["control_files"]
        for name in controlFiles.split(","):
            name = name.strip()
            if os.path.exists(name):
                os.remove(name)

    def RunInSqlplus(self, fileName, sql):
        self.SetEnvironment()
        fullFileName = os.path.join(self.adminDir, "scripts", fileName)
        outFile = self.__CreateFile(fullFileName)
        outFile.write("whenever sqlerror exit failure\n")
        outFile.write("connect %s as sysdba\n" % self.connectString)
        outFile.write(sql)
        outFile.write("\nexit\n")
        outFile.close()
        sqlplusBin = os.path.join(self.binDir, "sqlplus")
        self.__RunCommand(sqlplusBin, "-s", "/nolog", "@%s" % fullFileName)

    def RunRecoveryManagerSession(self, fileName, session):
        self.SetEnvironment()
        fullFileName = os.path.join(self.adminDir, "scripts", fileName)
        outFile = self.__CreateFile(fullFileName)
        outFile.write("connect target %s\n" % self.connectString)
        outFile.write("\n".join(session.inputLines))
        outFile.write("\nexit\n")
        outFile.close()
        rmanBin = os.path.join(self.binDir, "rman")
        self.__RunCommand(rmanBin, "@%s" % fullFileName)

    def SetEnvironment(self):
        cx_Logging.Debug("setting environment for %s", self)
        os.environ["ORACLE_SID"] = self.sid
        os.environ["ORACLE_HOME"] = self.oracleHome
        self.__PrependPathEnvVar("PATH", self.binDir)
        if sys.platform != "win32":
            self.__PrependPathEnvVar("LD_LIBRARY_PATH", self.libDir)

    def Start(self):
        if self.hasService:
            self.service.Start()
        if self.IsAvailable():
            cx_Logging.Trace("Database %s already started.", self.sid)
        else:
            cx_Logging.Trace("Starting database %s...", self.sid)
            self.RunInSqlplus("startup.sql", "startup")
            cx_Logging.Trace("Database %s started.", self.sid)

    def Stop(self, mode = ""):
        aborting = (mode.lower() == "abort")
        isAvailable = self.IsAvailable()
        if isAvailable and not aborting:
            self.WriteDiskConfigFile()
        if self.hasService:
            self.service.Stop()
        elif isAvailable:
            cx_Logging.Trace("Stopping database %s...", self.sid)
            self.RunInSqlplus("shutdown.sql", "shutdown %s" % mode)
            cx_Logging.Trace("Database %s stopped.", self.sid)
        else:
            cx_Logging.Trace("Database %s already stopped.", self.sid)

    def WriteActualParameterFile(self, parameters = None):
        if parameters is None:
            parameters = self.info.ExportParameterFile()
        outFile = self.__CreateFile(self.actualParameterFileName)
        outFile.write(parameters)

    def WriteDiskConfigFile(self, entries = None):
        if entries is not None:
            for entry in entries:
                self.__CreateDirectory(entry)
        else:
            entries = self.GetDirectories(includeDataFiles = False)
            entries.extend(self.info.GetDataFiles())
        entries.sort()
        outFile = self.__CreateFile(self.diskConfigFileName)
        for entry in entries:
            print >> outFile, entry

    def WriteEnvironmentConfigFile(self):
        outFile = self.__CreateFile(self.envConfigFileName)
        print >> outFile, "[Environment]"
        print >> outFile, "OracleHome=%s" % self.oracleHome
        print >> outFile, "StartMode=%s" % self.startMode

