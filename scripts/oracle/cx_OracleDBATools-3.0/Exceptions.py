"""
Defines exceptions used by the build tools.
"""

import cx_Exceptions

class CommandFailed(cx_Exceptions.BaseException):
    message = "Command %(command)s failed with exit code %(exitCode)s."


class DatabaseAlreadyExists(cx_Exceptions.BaseException):
    message = "Database %(sid)s already exists."


class DatabaseNotStarted(cx_Exceptions.BaseException):
    message = "Database %(sid)s not started."


class InvalidExtension(cx_Exceptions.BaseException):
    message = "Extension must be one of .tar, .tar.gz, .tgz, .tar.bz2, .tbz2."


class MissingControlFileRecordSection(cx_Exceptions.BaseException):
    message = "Missing control file record section %(name)s."


class MissingDatabaseType(cx_Exceptions.BaseException):
    message = "No section defined for database type %(typeName)s."


class MissingDefaultDatabaseType(cx_Exceptions.BaseException):
    message = "No section defined for default database type."


class MissingFile(cx_Exceptions.BaseException):
    message = "Missing file named %(name)s."


class MissingFileInArchive(cx_Exceptions.BaseException):
    message = "Missing file in archive named %(name)s."


class MissingOracleDriver(cx_Exceptions.BaseException):
    message = "Missing cx_Oracle driver for %(version)s installation."


class MissingOracleInstallation(cx_Exceptions.BaseException):
    message = "Cannot locate Oracle installation."

