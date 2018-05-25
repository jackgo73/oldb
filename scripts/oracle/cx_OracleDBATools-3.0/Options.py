"""
Common options.
"""

import cx_OptionParser
import os
import sys

if sys.platform == "win32":
    defaultForPlatform = r"C:\Oracle\OracleControl.ini"
else:
    defaultForPlatform = "/etc/oracle/OracleControl.ini"
defaultConfigFileName = os.environ.get("CX_ORACLE_ADMIN", defaultForPlatform)

CONFIG_FILE_NAME = cx_OptionParser.Option("--config-file-name",
        metavar = "FILE", default = defaultConfigFileName,
        help = "the name of the file to read for configuration information")

NO_PROMPTS = cx_OptionParser.Option("--no-prompts", dest = "prompts",
        default = True, action = "store_false",
        help = "do not issue any prompts and accept all defaults")

NO_START = cx_OptionParser.Option("--no-start", action = "store_true",
        help = "do not start the database if it is not already started")

NO_STOP = cx_OptionParser.Option("--no-stop", action = "store_true",
        help = "do not stop the database if it is not already stopped")

REPLACE_EXISTING = cx_OptionParser.Option("--replace-existing",
        action = "store_true",
        help = "replace the database if it already exists")

SHUTDOWN_MODE = cx_OptionParser.Option("--shutdown-mode", metavar = "MODE",
        default = "immediate",
        help = "the mode for shutting down the database; "
               "this must be a valid option for the SQL*Plus shutdown command")

SYS_PASSWORD = cx_OptionParser.Option("--sys-password", metavar = "STR",
        help = "the sys password for the database")

TNSENTRY = cx_OptionParser.Option("--tnsentry", metavar = "STR",
        help = "the TNS entry for the database; this is only required if you "
               "are running under Windows Terminal Services "
               "(NOTE: Plug-n-Play listeners do not work with this "
               "option)")

