"""
Defines the classes for managing backups.
"""

import cPickle
import cx_Logging
import cx_ShellUtils
import cx_Utils
import os
import shutil
import tarfile
import tempfile

import Database
import Exceptions
import Utils

class BackupSet(object):
    archiveDirName = "archive"
    infoFileName = "info.dat"
    controlFileName = "controlfile.dbf"

    def __init__(self, backupName, database = None):
        self.database = database
        self.backupName = os.path.normpath(os.path.abspath(backupName))
        self.isTarFile = False
        for ext in (".tar", ".tar.gz", ".tgz", ".tar.bz2", ".tbz2"):
            if not self.backupName.endswith(ext):
                continue
            self.isTarFile = True
            self.baseArchiveName = \
                    os.path.basename(self.backupName[:-len(ext)])
            if ext in (".tar.gz", ".tgz"):
                self.compressionMode = "gz"
            elif ext in (".tar.bz2", ".tbz2"):
                self.compressionMode = "bz2"
            else:
                self.compressionMode = ""
            break
        if not self.isTarFile and "." in backupName:
            raise Exceptions.InvalidExtension()

    def __BackupDatabaseToDir(self, dirName, offline):
        infoFileName = os.path.join(dirName, self.infoFileName)
        controlFileName = os.path.join(dirName, self.controlFileName)
        archiveDirName = os.path.join(dirName, self.archiveDirName)
        if not offline and not os.path.exists(archiveDirName):
            os.makedirs(archiveDirName)
        backupFileNames = [infoFileName, controlFileName]
        info = self.database.info
        if not offline:
            info.PopulateRecoverStartSequence(self.database)
        session = Utils.RecoveryManagerSession()
        if offline:
            session.AddCommand("shutdown immediate")
            session.AddCommand("startup mount")
        copyObjects = ["current controlfile to '%s'" % controlFileName]
        for dataFile in info.dataFiles:
            targetFileName = os.path.join(dirName, dataFile.backupName)
            backupFileNames.append(targetFileName)
            copyObjects.append("datafile '%s' to '%s'" % \
                    (dataFile.name, targetFileName))
        session.AddCommand("copy %s", ",\n".join(copyObjects))
        if offline:
            session.AddCommand("alter database open")
        self.database.RunRecoveryManagerSession("backup.rmn", session)
        if not offline:
            logs = info.PopulateRecoverChangeNumber(self.database)
            for archivedLogName in logs:
                targetName = os.path.join(archiveDirName,
                        os.path.basename(archivedLogName))
                backupFileNames.append(targetName)
                cx_ShellUtils.Copy(archivedLogName, targetName)
        cPickle.dump(info, file(infoFileName, "wb"), cPickle.HIGHEST_PROTOCOL)
        return backupFileNames

    def __ExtractFile(self, tarInfo, targetName):
        cx_Logging.Info("extracting %s as %s", tarInfo.name, targetName)
        sourceFile = self.backupFile.extractfile(tarInfo)
        targetFile = file(targetName, "wb")
        shutil.copyfileobj(sourceFile, targetFile, 1048576)

    def __VerifyFileExists(self, fileName):
        if not os.path.exists(fileName):
            raise Exceptions.MissingFile(name = fileName)

    def __VerifyFileInTar(self, expectedName):
        tarInfo = self.backupFile.next()
        if tarInfo is None or os.path.basename(tarInfo.name) != expectedName:
            raise Exceptions.MissingFileInArchive(name = expectedName)
        return tarInfo

    def Backup(self, offline):
        if self.isTarFile:
            baseDirName = os.path.dirname(self.backupName)
            dirName = tempfile.mkdtemp(prefix = "BackupDB_", dir = baseDirName)
        else:
            dirName = self.backupName
            if not os.path.exists(dirName):
                os.makedirs(dirName)
        backupFileNames = self.__BackupDatabaseToDir(dirName, offline)
        if self.isTarFile:
            mode = "w|%s" % self.compressionMode
            backupFile = tarfile.open(self.backupName, mode)
            for fileName in backupFileNames:
                archiveName = os.path.join(self.baseArchiveName,
                        fileName[len(dirName) + 1:])
                cx_Logging.Info("adding %s to archive", archiveName)
                backupFile.add(fileName, archiveName)
            backupFile.close()
            cx_ShellUtils.Remove(dirName)

    def PrepareForRestore(self, manager, sysPassword, tnsentry):
        if self.isTarFile:
            mode = "r|%s" % self.compressionMode
            self.backupFile = tarfile.open(self.backupName, mode)
            tarInfo = self.__VerifyFileInTar(self.infoFileName)
            databaseInfo = cPickle.load(self.backupFile.extractfile(tarInfo))
        else:
            infoFileName = os.path.join(self.backupName, self.infoFileName)
            self.__VerifyFileExists(infoFileName)
            databaseInfo = cPickle.load(file(infoFileName, "rb"))
        self.database = Database.Database(manager, databaseInfo.sid,
                databaseInfo.oracleHome, databaseInfo.startMode, sysPassword,
                tnsentry)
        self.database.info = databaseInfo

    def Restore(self, database, mapping):
        database.SetEnvironment()
        if self.isTarFile:
            tarInfo = self.__VerifyFileInTar(self.controlFileName)
        else:
            controlFileName = os.path.join(self.backupName,
                    self.controlFileName)
            self.__VerifyFileExists(controlFileName)
        if mapping is None:
            controlFiles = database.controlFiles
            primaryName = controlFiles[0]
            secondaryNames = controlFiles[1:]
            if self.isTarFile:
                self.__ExtractFile(tarInfo, primaryName)
            else:
                cx_ShellUtils.Copy(controlFileName, primaryName)
            for fileName in secondaryNames:
                cx_ShellUtils.Copy(primaryName, fileName)
        for dataFile in self.database.info.dataFiles:
            if mapping is None:
                targetName = dataFile.name
            else:
                targetName = mapping.MappedFileName(dataFile.name)
            if self.isTarFile:
                tarInfo = self.__VerifyFileInTar(dataFile.backupName)
                self.__ExtractFile(tarInfo, targetName)
            else:
                sourceName = os.path.join(self.backupName, dataFile.backupName)
                self.__VerifyFileExists(sourceName)
                cx_ShellUtils.Copy(sourceName, targetName)
        if not self.isTarFile:
            archiveDir = os.path.join(self.backupName, self.archiveDirName)
        elif self.database.info.recoverStartSequence is not None:
            archiveDir = tempfile.mkdtemp(prefix = "RestoreDB_")
            while True:
                tarInfo = self.backupFile.next()
                if tarInfo is None:
                    break
                targetName = os.path.join(archiveDir,
                        os.path.basename(tarInfo.name))
                self.__ExtractFile(tarInfo, targetName)
        else:
            archiveDir = None
        recoverClause = self.database.info.GetRecoverClause(archiveDir)
        includeStartup = not database.IsAvailable()
        if mapping is None:
            sql = database.info.ExportRestoreScript(recoverClause,
                    includeStartup)
        else:
            info = database.info
            sql = info.ExportControlFile(recoverClause = recoverClause,
                    includeStartup = includeStartup)
        database.RunInSqlplus("restore.sql", sql)
        if self.isTarFile and archiveDir is not None:
            cx_ShellUtils.Remove(archiveDir)

