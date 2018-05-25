"""
Remove an Oracle database from the machine.
"""

import cx_Logging
import cx_LoggingOptions
import cx_OptionParser

import Manager
import Options

# parse command line
parser = cx_OptionParser.OptionParser("RemoveDB")
parser.AddOption(Options.CONFIG_FILE_NAME)
parser.AddOption(Options.SYS_PASSWORD)
parser.AddOption(Options.TNSENTRY)
parser.AddOption("--ignore-if-missing", default = False, action = "store_true",
        help = "do not raise an error if the database is missing")
cx_LoggingOptions.AddOptions(parser)
parser.AddArgument("sids", required = True,
        help = "the SID(s) of the database(s) to remove, separated by commas")
options = parser.Parse()
cx_LoggingOptions.ProcessOptions(options)

# perform the work
manager = Manager.Manager(options.configFileName)
database = manager.DatabaseFromEnvironment(options.sysPassword,
        options.tnsentry)
if database is not None:
    database.Remove()
else:
    for sid in options.sids.split(","):
        database = manager.DatabaseBySid(sid, options.ignoreIfMissing)
        if database is not None:
            manager.ExecuteForDatabase(database)
        else:
            cx_Logging.Warning("Database %s does not exist.", sid)

