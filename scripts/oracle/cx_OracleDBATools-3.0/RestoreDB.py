"""
Restores an Oracle database.
"""

import cx_LoggingOptions
import cx_OptionParser
import cx_ReadLine
import os

import BackupSet
import Database
import Exceptions
import Manager
import Options
import Utils

# parse command line
parser = cx_OptionParser.OptionParser("RestoreDB")
parser.AddOption(Options.CONFIG_FILE_NAME)
parser.AddOption(Options.NO_PROMPTS)
parser.AddOption(Options.REPLACE_EXISTING)
parser.AddOption(Options.SYS_PASSWORD)
parser.AddOption(Options.TNSENTRY)
parser.AddOption("--as-sid", metavar = "SID",
        help = "restore the database as this SID rather than the one "
               "embedded in the backup file")
cx_LoggingOptions.AddOptions(parser)
parser.AddArgument("baseFileName", required = True,
        help = "the base name of the files to create; the extension .rmn will "
               "be added to this for the RMAN backup file and the extension "
               ".info will be added for the associated database info file")
options = parser.Parse()
cx_LoggingOptions.ProcessOptions(options)

# perform the work
manager = Manager.Manager(options.configFileName)
backupSet = BackupSet.BackupSet(options.baseFileName)
backupSet.PrepareForRestore(manager, options.sysPassword, options.tnsentry)
databaseFromEnv = manager.DatabaseFromEnvironment(options.sysPassword,
        options.tnsentry)
if databaseFromEnv:
    if options.replaceExisting:
        sid = options.asSid or databaseFromEnv.sid
        existingDatabase = manager.DatabaseBySid(sid, ignoreIfMissing = True)
        if existingDatabase is not None:
            existingDatabase.Remove()
    mapping = None
    database = backupSet.database
    if options.asSid:
        newDatabase = Database.Database(manager, options.asSid,
                databaseFromEnv.oracleHome, backupSet.database.startMode,
                options.sysPassword)
        mapping = Utils.Mapping(newDatabase, backupSet.database,
                options.prompts)
        newDatabase.info = database.info.Clone(newDatabase.sid, mapping)
        database = newDatabase
    database.Initialize(dirs = database.GetDirectories())
    backupSet.Restore(database, mapping)
else:
    sid = options.asSid or backupSet.database.sid
    existingDatabase = manager.DatabaseBySid(sid, ignoreIfMissing = True)
    if existingDatabase is not None:
        if not options.replaceExisting:
            raise Exceptions.DatabaseAlreadyExists(sid = sid)
    del existingDatabase
    if options.asSid and options.prompts:
        origValue = Utils.NormalizePath(backupSet.database.oracleHome)
        backupSet.database.oracleHome = \
                cx_ReadLine.ReadLine("Map %s to" % origValue, origValue)
    manager.ExecuteForDatabase(backupSet.database)

