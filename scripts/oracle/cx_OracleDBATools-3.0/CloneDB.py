"""
Starts up an Oracle database.
"""

import cx_Logging
import cx_LoggingOptions
import cx_OptionParser
import cx_ShellUtils
import os
import sys

import Database
import Exceptions
import Manager
import Options
import Utils

# parse command line
parser = cx_OptionParser.OptionParser("CloneDB")
parser.AddOption(Options.CONFIG_FILE_NAME)
parser.AddOption(Options.SYS_PASSWORD)
parser.AddOption(Options.TNSENTRY)
parser.AddOption(Options.NO_PROMPTS)
parser.AddOption(Options.REPLACE_EXISTING)
parser.AddOption(Options.NO_START)
parser.AddOption("--offline", default = False, action = "store_true",
        help = "perform an offline copy with the database shut down")
cx_LoggingOptions.AddOptions(parser)
parser.AddArgument("origSid", required = True,
        help = "the SID of the database to clone")
parser.AddArgument("newSid", required = True,
        help = "the SID of the database to create")
options = parser.Parse()
cx_LoggingOptions.ProcessOptions(options)

# make sure the target database does not exist
manager = Manager.Manager(options.configFileName)
database = manager.DatabaseBySid(options.newSid, ignoreIfMissing = True)
if database is not None and not options.replaceExisting:
    raise Exceptions.DatabaseAlreadyExists(sid = options.newSid)

# perform the work
database = manager.DatabaseFromEnvironment(options.sysPassword,
        options.tnsentry)
if database is None:
    database = manager.DatabaseBySid(options.origSid)
    manager.ExecuteForDatabase(database)
else:
    if options.replaceExisting:
        existingDatabase = manager.DatabaseBySid(options.newSid,
                ignoreIfMissing = True)
        if existingDatabase is not None:
            existingDatabase.Remove()
    if not database.IsAvailable():
        if options.noStart:
            raise Exceptions.DatabaseNotStarted(sid = database.sid)
        database.Start()
    newDatabase = Database.Database(manager, options.newSid,
            database.oracleHome, database.startMode, database.sysPassword)
    mapping = Utils.Mapping(newDatabase, database, options.prompts)
    newDatabase.Clone(database, mapping, options.offline)

