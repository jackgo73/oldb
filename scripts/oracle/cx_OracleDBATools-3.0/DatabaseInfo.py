"""
Define classes for storing information about a database.
"""

import cx_Logging
import os

import Exceptions
import Utils

class DatabaseInfo(object):
    dirParameters = [
            "audit_file_dest",
            "background_dump_dest",
            "core_dump_dest",
            "log_archive_duplex_dest",
            "user_dump_dest"
    ]
    fileParameters = [
            "control_files"
    ]
    removeParameters = [
            "dispatchers",
            "ifile",
            "instance_name",
            "service_names"
    ]
    sizeParameters = [
            "db_cache_size",
            "java_pool_size",
            "large_pool_size",
            "pga_aggregate_target",
            "shared_pool_size"
    ]

    def __repr__(self):
        return "<%s %s (%s)>" % \
                (self.__class__.__name__, self.sid, self.oracleHome)

    def __GetControlFileInfo(self, cursor):
        cursor.execute("""
                select
                  type,
                  records_total
                from v$controlfile_record_section""")
        values = dict(cursor)
        try:
            self.maxLogFiles = int(values["REDO LOG"])
            self.maxLogHistory = int(values["LOG HISTORY"])
            self.maxDataFiles = int(values["DATAFILE"])
            self.maxInstances = int(values["REDO THREAD"])
        except KeyError as name:
            raise Exceptions.MissingControlFileRecordSection(name = name)
        cursor.execute("select dimlm from x$kccdi")
        self.maxLogMembers = int(cursor.fetchone()[0])
        cursor.execute("select name, log_mode from v$database")
        self.databaseName, self.archiveLogMode = cursor.fetchone()
        cursor.execute("""
                select value
                from nls_database_parameters
                where parameter = 'NLS_CHARACTERSET'""")
        self.characterSet, = cursor.fetchone()

    def __GetDataFiles(self, cursor):
        cursor.execute("""
                select
                  file_id,
                  file_name
                from dba_data_files
                order by file_id""")
        self.dataFiles = [DataFileInfo(*r) for r in cursor]
        cursor.execute("""
                select
                  file_name,
                  bytes,
                  tablespace_name,
                  autoextensible,
                  increment_by,
                  maxbytes
                from dba_temp_files""")
        self.tempFiles = [TempFileInfo(*r) for r in cursor]

    def __GetLogFiles(self, cursor):
        self.logFileGroups = []
        cursor.execute("select group#, bytes from v$log order by group#")
        for groupNumber, bytes in cursor.fetchall():
            cursor.execute("select member from v$logfile where group# = :gn",
                    gn = groupNumber)
            members = [n for n, in cursor]
            group = LogFileGroupInfo(groupNumber, bytes, members)
            self.logFileGroups.append(group)

    def __GetParameters(self, cursor):
        cursor.execute("""
                select
                  name,
                  value
                from v$parameter
                where isdefault = 'FALSE'""")
        self.parameters = dict(cursor)

    def Clone(self, sid, mapping):
        info = DatabaseInfo()
        info.sid = sid
        info.databaseName = sid
        info.oracleHome = self.oracleHome
        info.startMode = self.startMode
        info.maxLogFiles = self.maxLogFiles
        info.maxLogHistory = self.maxLogHistory
        info.maxDataFiles = self.maxDataFiles
        info.maxInstances = self.maxInstances
        info.maxLogMembers = self.maxLogMembers
        info.archiveLogMode = self.archiveLogMode
        info.characterSet = self.characterSet
        info.logFileGroups = [g.Clone(mapping) for g in self.logFileGroups]
        info.dataFiles = [d.Clone(mapping) for d in self.dataFiles]
        info.tempFiles = [t.Clone(mapping) for t in self.tempFiles]
        info.parameters = self.parameters.copy()
        for name in self.fileParameters:
            value = info.parameters.get(name)
            if value is None:
                continue
            files = [mapping.MappedFileName(n.strip()) \
                    for n in value.split(",")]
            info.parameters[name] = ", ".join(files)
        for name in self.dirParameters:
            value = self.parameters.get(name)
            if value is not None:
                info.parameters[name] = mapping.MappedDir(value)
        for name, value in self.parameters.iteritems():
            if not name.startswith("log_archive_dest") \
                    or name.startswith("log_archive_dest_state"):
                continue
            parts = value.split("=")
            if len(parts) == 1:
                newValue = mapping.MappedDir(parts[0])
            else:
                if parts[0].lower() != "location":
                    continue
                subParts = parts[1].split()
                subParts[0] = mapping.MappedDir(subParts[0])
                parts[1] = " ".join(subParts)
                newValue = "=".join(parts)
            info.parameters[name] = newValue
        info.parameters["db_name"] = info.databaseName
        for name in self.removeParameters:
            if name in info.parameters:
                del info.parameters[name]
        return info

    def ExportControlFile(self, createStoredParameterFile = False,
            recoverClause = None, includeStartup = True):
        syntax = []
        if createStoredParameterFile:
            syntax.append("CREATE SPFILE FROM PFILE;")
            syntax.append("")
        if includeStartup:
            syntax.append("STARTUP NOMOUNT")
            syntax.append("")
        syntax.append('CREATE CONTROLFILE SET DATABASE "%s" RESETLOGS' % \
                self.databaseName)
        syntax.append("    MAXLOGFILES %r" % self.maxLogFiles)
        syntax.append("    MAXLOGMEMBERS %r" % self.maxLogMembers)
        syntax.append("    MAXDATAFILES %r" % self.maxDataFiles)
        syntax.append("    MAXINSTANCES %r" % self.maxInstances)
        syntax.append("    MAXLOGHISTORY %r" % self.maxLogHistory)
        syntax.append("LOGFILE")
        groups = ",\n    ".join([g.GetSyntax() for g in self.logFileGroups])
        syntax.append("    %s" % groups)
        syntax.append("DATAFILE")
        fileNames = ["    '%s'" % f.name for f in self.dataFiles]
        syntax.append(",\n".join(fileNames))
        syntax.append(self.archiveLogMode)
        syntax.append("CHARACTER SET %s;" % self.characterSet)
        syntax.append("")
        if recoverClause is not None:
            syntax.append(recoverClause)
            syntax.append("")
        syntax.append("ALTER DATABASE OPEN RESETLOGS;")
        syntax.append("")
        for tempFile in self.tempFiles:
            syntax.append(tempFile.GetSyntax())
        return "".join([s + "\n" for s in syntax])

    def ExportParameterFile(self):
        syntax = []
        names = self.parameters.keys()
        names.sort()
        for name in names:
            if name.lower() == "ifile":
                continue
            value = self.parameters[name]
            if name in self.sizeParameters:
                try:
                    longValue = long(value)
                except ValueError:
                    pass
                else:
                    value = FormattedSize(longValue)
            elif value is not None and "=" in value:
                value = "'%s'" % value
            elif value is None:
                value = '""'
            syntax.append("%s=%s" % (name, value))
        return "".join([s + "\n" for s in syntax])

    def ExportRestoreScript(self, recoverClause = None, includeStartup = True):
        syntax = []
        if includeStartup:
            syntax.append("STARTUP MOUNT")
        if recoverClause is not None:
            syntax.append(recoverClause)
        syntax.append("ALTER DATABASE OPEN RESETLOGS;")
        for tempFile in self.tempFiles:
            syntax.append(tempFile.GetSyntax())
        return "".join([s + "\n" for s in syntax])

    def GetDataFiles(self, includeTempFiles = True):
        logFiles = [m for g in self.logFileGroups for m in g.members]
        files = [d.name for d in self.dataFiles] + logFiles
        if includeTempFiles:
            files.extend([t.name for t in self.tempFiles])
        return files

    def GetDirectories(self, includeDataFiles = True):
        if includeDataFiles:
            files = self.GetDataFiles()
        else:
            files = []
        for name in self.fileParameters:
            value = self.parameters.get(name)
            if value is not None:
                files.extend([Utils.NormalizePath(n.strip()) \
                        for n in value.split(",")])
        dirs = {}
        for name in files:
            name = Utils.NormalizePath(name)
            dirs[os.path.dirname(name)] = None
        for name in self.dirParameters:
            value = self.parameters.get(name)
            if value is not None:
                value = Utils.NormalizePath(value)
                dirs[value] = None
        for name, value in self.parameters.iteritems():
            if not name.startswith("log_archive_dest") \
                    or name.startswith("log_archive_dest_state"):
                continue
            parts = value.split("=")
            if len(parts) == 1:
                valueToCheck = parts[0]
            elif parts[0].lower() != "location":
                continue
            else:
                subParts = parts[1].split()
                valueToCheck = subParts[0]
            value = Utils.NormalizePath(valueToCheck)
            dirs[value] = None
        return dirs.keys()

    def GetRecoverClause(self, archiveLogDir):
        if self.recoverStartSequence is None:
            return None
        clause1 = "recover automatic from '%s' " % archiveLogDir
        clause2 = "until change %s using backup controlfile;" % \
                self.recoverChangeNumber
        return clause1 + clause2

    def PopulateFromDatabase(self, database):
        self.sid = database.sid
        self.oracleHome = database.oracleHome
        self.startMode = database.startMode
        cursor = database.connection.cursor()
        self.__GetControlFileInfo(cursor)
        self.__GetLogFiles(cursor)
        self.__GetDataFiles(cursor)
        self.__GetParameters(cursor)
        self.recoverStartSequence = self.recoverChangeNumber = None

    def PopulateRecoverChangeNumber(self, database):
        cursor = database.connection.cursor()
        cursor.execute("alter system archive log current")
        cursor.execute("""
                select
                  name,
                  next_change#
                from v$archived_log
                where sequence# >= :sequenceNumber
                  and resetlogs_change# =
                    ( select resetlogs_change#
                      from v$database
                    )
                order by sequence#""",
                sequenceNumber = self.recoverStartSequence)
        archivedLogs = []
        for name, nextChangeNumber in cursor:
            archivedLogs.append(name)
            self.recoverChangeNumber = nextChangeNumber
        cx_Logging.Info("Recover change number is %s",
                self.recoverChangeNumber)
        return archivedLogs

    def PopulateRecoverStartSequence(self, database):
        cursor = database.connection.cursor()
        cursor.execute("""
                select sequence#
                from v$log
                where status = 'CURRENT'""")
        startSequence, = cursor.fetchone()
        self.recoverStartSequence = int(startSequence)
        cx_Logging.Info("Log sequence is currently %s",
                self.recoverStartSequence)


class DataFileInfo(object):

    def __init__(self, fileId, name):
        self.id = fileId
        self.name = name
        self.backupName = "file_%s.dbf" % fileId

    def __repr__(self):
        return "<%s %s>" % (self.__class__.__name__, self.name)

    def Clone(self, mapping):
        return DataFileInfo(self.id, mapping.MappedFileName(self.name))


class LogFileGroupInfo(object):

    def __init__(self, groupNumber, size, members):
        self.groupNumber = groupNumber
        self.size = FormattedSize(size)
        self.members = members
        self.members.sort()

    def __repr__(self):
        return "<%s %s>" % (self.__class__.__name__, self.members)

    def Clone(self, mapping):
        return LogFileGroupInfo(self.groupNumber, self.size,
                [mapping.MappedFileName(n) for n in self.members])

    def GetSyntax(self):
        members = ",".join(["'%s'" % m for m in self.members])
        return "GROUP %s (%s) size %s" % \
                (self.groupNumber, members, self.size)


class TempFileInfo(object):

    def __init__(self, name, size, tablespaceName, autoExtensible = "NO",
            incrementBy = 0, maxBytes = 0):
        self.name = name
        self.size = FormattedSize(size)
        self.tablespaceName = tablespaceName
        self.autoExtensible = autoExtensible
        self.incrementBy = incrementBy
        self.maxBytes = FormattedSize(maxBytes)

    def __repr__(self):
        return "<%s %s>" % (self.__class__.__name__, self.name)

    def Clone(self, mapping):
        return TempFileInfo(mapping.MappedFileName(self.name), self.size,
                self.tablespaceName, self.autoExtensible, self.incrementBy,
                self.maxBytes)

    def GetSyntax(self):
        syntax = []
        syntax.append("ALTER TABLESPACE %s ADD TEMPFILE '%s'" % \
                (self.tablespaceName, self.name))
        syntax.append("    SIZE %s REUSE" % self.size)
        if self.autoExtensible == "YES":
            syntax.append("    AUTOEXTEND ON NEXT %s MAXSIZE %s" % \
                    (self.incrementBy, self.maxBytes))
        return "\n".join(syntax) + ";"


def FormattedSize(size):
    """Return the size formatted for use in a SQL statement. Note that a
       negative size is assumed to be unlimited and that if the value is
       already a string it is assumed to be formatted already."""
    if isinstance(size, str):
        return size
    if size < 0:
        return "unlimited"
    kilobytes, remainder = divmod(size, 1024)
    if not remainder:
        megabytes, remainder = divmod(kilobytes, 1024)
        if not remainder:
            return "%ldm" % megabytes
        else:
            return "%ldk" % kilobytes
    return str(size)

