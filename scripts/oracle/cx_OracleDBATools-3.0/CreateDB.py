"""
Creates an Oracle database.
"""

import cx_ClassLibrary
import cx_LoggingOptions
import cx_OptionParser
import socket

import Database
import Exceptions
import Options
import Manager

# parse command line
parser = cx_OptionParser.OptionParser("CreateDB")
parser.AddOption(Options.CONFIG_FILE_NAME)
parser.AddOption("--type", dest = "databaseType", metavar = "STR",
        help = "the type of database to create; if omitted the default "
               "type is used")
parser.AddOption("--start-mode", default = "Manual", metavar = "MODE",
        help = "the start mode for the database (Manual or Auto)")
parser.AddOption("--sys-password", metavar = "STR",
        default = socket.gethostname().split(".")[0],
        help = "the sys password for the new database; if omitted the "
               "name of the machine is used")
parser.AddOption(Options.TNSENTRY)
cx_LoggingOptions.AddOptions(parser)
parser.AddArgument("sid", required = True,
        help = "the SID to use for the database to create")
parser.AddArgument("substitutions", keywords = True,
        help = 'this is a set of "name=value" pairs that override the '
               'substitutions specified in the config file.')
options = parser.Parse()
cx_LoggingOptions.ProcessOptions(options)

# perform the work
manager = Manager.Manager(options.configFileName)
databaseType = manager.DatabaseTypeByName(options.databaseType)
database = manager.DatabaseFromEnvironment(options.sysPassword,
        options.tnsentry)
if database is None:
    database = Database.Database(manager, options.sid, databaseType.oracleHome,
            options.startMode)
    manager.ExecuteForDatabase(database)
else:
    existingDatabase = manager.DatabaseBySid(options.sid,
            ignoreIfMissing = True)
    if existingDatabase is not None:
        raise Exceptions.DatabaseAlreadyExists(sid = options.sid)
    database.Create(databaseType, options.substitutions)

