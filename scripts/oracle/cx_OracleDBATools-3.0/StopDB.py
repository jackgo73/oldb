"""
Stop an Oracle database.
"""

import cx_Logging
import cx_LoggingOptions
import cx_OptionParser

import Manager
import Options

# parse command line
parser = cx_OptionParser.OptionParser("StopDB")
parser.AddOption(Options.CONFIG_FILE_NAME)
parser.AddOption(Options.SYS_PASSWORD)
parser.AddOption(Options.TNSENTRY)
parser.AddOption(Options.SHUTDOWN_MODE)
parser.AddOption("--all", action = "store_true",
        help = "stop all configured databases")
cx_LoggingOptions.AddOptions(parser)
parser.AddArgument("sids",
        help = "the SID(s) of the database(s) to stop, separated by commas")
options = parser.Parse()
cx_LoggingOptions.ProcessOptions(options)

# perform the work
manager = Manager.Manager(options.configFileName)
database = manager.DatabaseFromEnvironment(options.sysPassword,
        options.tnsentry)
if database is not None:
    database.Stop(options.shutdownMode)
else:
    if options.all:
        sids = manager.AllSids()
    elif options.sids:
        sids = options.sids.split(",")
    else:
        sids = []
        cx_Logging.Warning("Nothing to do.")
    for sid in sids:
        database = manager.DatabaseBySid(sid)
        manager.ExecuteForDatabase(database)

