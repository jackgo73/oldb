"""
Backs up an Oracle database.
"""

import cx_LoggingOptions
import cx_OptionParser
import os
import sys

import BackupSet
import Exceptions
import Manager
import Options

# parse command line
parser = cx_OptionParser.OptionParser("BackupDB")
parser.AddOption(Options.CONFIG_FILE_NAME)
parser.AddOption(Options.SYS_PASSWORD)
parser.AddOption(Options.TNSENTRY)
parser.AddOption(Options.NO_START)
parser.AddOption("--offline", default = False, action = "store_true",
        help = "perform an offline backup with the database shut down")
cx_LoggingOptions.AddOptions(parser)
parser.AddArgument("sid", required = True,
        help = "the SID of the database to backup")
parser.AddArgument("backupName", required = True,
        help = "the name of the directory to create and populate with the "
               "files required to restore the database")
options = parser.Parse()
cx_LoggingOptions.ProcessOptions(options)

# perform the work
manager = Manager.Manager(options.configFileName)
database = manager.DatabaseFromEnvironment(options.sysPassword,
        options.tnsentry)
if database is not None:
    if not database.IsAvailable():
        if options.noStart:
            raise Exceptions.DatabaseNotStarted(sid = database.sid)
        database.Start()
    set = BackupSet.BackupSet(options.backupName, database)
    set.Backup(options.offline)
else:
    database = manager.DatabaseBySid(options.sid)
    manager.ExecuteForDatabase(database)

