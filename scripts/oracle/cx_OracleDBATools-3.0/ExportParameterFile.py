"""
Export the parameter file for the database which will be included in any
backups.
"""

import cx_LoggingOptions
import cx_OptionParser
import sys

import Exceptions
import Manager
import Options

# parse command line
parser = cx_OptionParser.OptionParser("ExportControlFile")
parser.AddOption(Options.CONFIG_FILE_NAME)
parser.AddOption(Options.SYS_PASSWORD)
parser.AddOption(Options.TNSENTRY)
cx_LoggingOptions.AddOptions(parser)
parser.AddArgument("sid", required = True,
        help = "the SID of the database to export the control file for")
parser.AddArgument("fileName",
        help = "the name of the file in which to place the output")
options = parser.Parse()
cx_LoggingOptions.ProcessOptions(options)

# create the manager
manager = Manager.Manager(options.configFileName)
database = manager.DatabaseFromEnvironment(options.sysPassword,
        options.tnsentry)
if database is not None:
    if database.IsAvailable():
        if options.fileName is not None:
            outFile = file(options.fileName, "w")
        else:
            outFile = sys.stdout
        outFile.write(database.info.ExportParameterFile())
    else:
        raise Exceptions.DatabaseNotStarted(sid = options.sid)
else:
    database = manager.DatabaseBySid(options.sid)
    manager.ExecuteForDatabase(database)

