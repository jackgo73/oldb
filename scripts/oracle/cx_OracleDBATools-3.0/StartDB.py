"""
Starts up an Oracle database.
"""

import cx_Logging
import cx_LoggingOptions
import cx_OptionParser

import Manager
import Options

# parse command line
parser = cx_OptionParser.OptionParser("StartDB")
parser.AddOption(Options.CONFIG_FILE_NAME)
parser.AddOption(Options.SYS_PASSWORD)
parser.AddOption(Options.TNSENTRY)
parser.AddOption("-r", "--restart", action = "store_true",
        help = "shut down the database first if already started")
parser.AddOption(Options.SHUTDOWN_MODE)
parser.AddOption("--all", action = "store_true",
        help = "start all configured databases")
parser.AddOption("--all-auto", action = "store_true",
        help = "start all configured databases set to automatic start")
cx_LoggingOptions.AddOptions(parser)
parser.AddArgument("sids",
        help = "the SID(s) of the database(s) to start, separated by commas")
options = parser.Parse()
cx_LoggingOptions.ProcessOptions(options)

# perform the work
manager = Manager.Manager(options.configFileName)
database = manager.DatabaseFromEnvironment(options.sysPassword,
        options.tnsentry)
if database is not None:
    if options.restart:
        database.Stop(options.shutdownMode)
    database.Start()
else:
    if options.all or options.allAuto:
        for sid in manager.AllSids():
            database = manager.DatabaseBySid(sid)
            if database.startMode.lower() == "auto" or options.all:
                manager.ExecuteForDatabase(database)
    elif options.sids:
        for sid in options.sids.split(","):
            database = manager.DatabaseBySid(sid)
            manager.ExecuteForDatabase(database)
    else:
        cx_Logging.Warning("Nothing to do.")

