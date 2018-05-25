=================
cx_OracleDBATools
=================

This document covers a cross platform set of tools for performing DBA type
activities with Oracle databases. These tools have been developed over the past
number of years and are designed to provide a consistent interface for the DBA
regardless of the platform on which they are running.

**NOTE:** These tools are a work in progress and are geared for people who are
reasonably comfortable with Oracle.  This means that while an attempt will be
made to maintain a stable interface for these tools, changes or extensions will
be made if there is a valid reason for it.

**NOTE:** These tools must be run on the machine where the database resides.

--------
Overview
--------

Environments
============

These tools have been known to work in the following environments:

Oracle Version:
    - Oracle 8i
    - Oracle 9i Release 2
    - Oracle 10g Release 1
    - Oracle 10g Release 2
    - Oracle 11g Release 1
    - Oracle 11g Release 2

Operating Systems:
    - Windows (32-bit and 64-bit)
    - Linux (32-bit and 64-bit)
    - SunOS 5.8
    - Compaq Tru64 v5.1
    - HP-UX 11


Conventions
===========

In the description of each tool, the following conventions are used for the
arguments and options:

    - Items enclosed in brackets ("[]") are optional
    - If an option is shown without an equals sign ("=") no value is expected
    - If an option is shown with an equals sign ("="), the equals sign may be
      replaced with a space

Common Options
==============

The following options are common to most of the tools:

+---------------------+-------------------------------------------------------+
| name                | description                                           |
+---------------------+-------------------------------------------------------+
| --config-file-name= | the name of the configuration file; see Configuration_|
|                     | for more information                                  |
+---------------------+-------------------------------------------------------+
| -h, --help          | display a brief usage description of the arguments and|
|                     | options and stop                                      |
+---------------------+-------------------------------------------------------+
| --log-file=         | the name of the file to log messages to or the words  |
|                     | ``stdout`` or ``stderr``; the default is ``stderr``   |
+---------------------+-------------------------------------------------------+
| --log-level=        | the level at which to log messages, one of debug (10),|
|                     | info (20), warning (30), error (40) or critical (50); |
|                     | the default is ``error``                              |
+---------------------+-------------------------------------------------------+
| --log-prefix=       | the prefix to use for log messages which is a mask    |
|                     | containing %i (id of the thread logging the message), |
|                     | %d (date at which the message was logged), %t (time at|
|                     | which the message was logged) or %l (level at which   |
|                     | the message was logged); the default is ``%t``        |
+---------------------+-------------------------------------------------------+
| --show-banner       | display the program name and version                  |
+---------------------+-------------------------------------------------------+
| --sys-password=     | the sys password for the database; this is not        |
|                     | required if you are part of the Oracle DBA group      |
+---------------------+-------------------------------------------------------+
| --tnsentry=         | the TNS entry for the database; usually not needed    |
+---------------------+-------------------------------------------------------+
| -t, --traceback     | when an error is encountered, display an internal     |
|                     | traceback stack                                       |
+---------------------+-------------------------------------------------------+
| --version           | display the version information and stop              |
+---------------------+-------------------------------------------------------+

-------------
Configuration
-------------

The tools utilize Oracle's Optimal Flexible Architecture for files. In
addition, a control file that defines key locations is also utilized.

OracleControl.ini
=================

Description
-----------

This file specifies the location of the Oracle installation and defines how
databases are created.  The tools will first look at the environment variable
``CX_ORACLE_ADMIN`` for a fully qualified file name. If this environment
variable is not set, then ``/etc/oracle/OracleControl.ini`` will be used for
Unix and ``c:\Oracle\OracleControl.ini`` will be used for Windows.

Structure
---------

The file is structured as an INI file with several sections. The first section
is mandatory and is named ``[General]``. Any other sections contain
configuration for database types.

The following options are valid in the ``[General]`` section:

    BaseDir

        This is the base directory for Oracle databases. The directory
        <BaseDir>/admin/<SID>/pfile will contain the parameter file
        (``init.ora``) and the directory <BaseDir>/admin/<SID>/config will
        contain a file to specify the files and directories used by the
        database (``disk.cfg``) and on platforms other than Windows, a file to
        specify the environment (``env.cfg``).


    DefaultType

        The name of the section which contains the default database type
        configuration.

The following options are valid in the database type sections:

    OracleHome

        The value to set the environment variable ORACLE_HOME to when
        interacting with the database.

    TemplateInitOra

        This is a template ``init.ora`` file. When a database is created this
        file is copied to <BaseDir>/admin/<SID>/pfile/init.ora with the
        substitutions below being performed.

    TemplateDirs

        This is a template file. When a database is created this file is used
        to determine which directories need to be created before the database
        is actually created. The substitutions below are performed before
        creating the directories.

    TemplateCreate

        This is a template script for creating databases.  When a database is
        created this file is copied to <BaseDir>/admin/<SID>/create/create.sql
        with the substitutions below being performed.


Template File Location
----------------------

If any of the file names in TemplateInitOra, TemplateDirs, or  TemplateCreate
are relative, they will be made absolute by prepending the directory where the
OracleControl.ini file is located.


Template Substitutions
----------------------

The following substitutions are performed when processing the template files:

+------------------+----------------------------------------------------------+
| Search Value     | Replacement Value                                        |
+------------------+----------------------------------------------------------+
| %(SID)s          | the SID of the database being created                    |
+------------------+----------------------------------------------------------+
| %(BASE_DIR)s     | <BaseDir>                                                |
+------------------+----------------------------------------------------------+
| %(ADMIN_DIR)s    | <BaseDir>/admin/<SID>                                    |
+------------------+----------------------------------------------------------+
| %(ORACLE_HOME)s  | <OracleHome>                                             |
+------------------+----------------------------------------------------------+
| %(SYS_PWD)s      | the sys password supplied on the command line            |
+------------------+----------------------------------------------------------+

In addition, note that user supplied substitutions can be performed as provided
on the command line.

**NOTE:** any other % that you have in the template file must be doubled.


------------
Backup Files
------------

The utilties BackupDB and RestoreDB create backup files or directories. The
type of file created depends on the extension of the file name given to the
utility. If the extension is not found in this table or the file name does not
have an extension, a directory with that name will be created instead and all
of the files will be placed inside that directory.

+------------------+----------------------------------------------------------+
| Extension        | Description                                              |
+------------------+----------------------------------------------------------+
| .tar             | TAR file, uncompressed                                   |
+------------------+----------------------------------------------------------+
| .tar.gz, .tgz    | TAR file, gzip compressed (faster, larger files)         |
+------------------+----------------------------------------------------------+
| .tar.bz2, .tbz2  | TAR file, bzip compressed (slower, smaller files)        |
+------------------+----------------------------------------------------------+


--------
BackupDB
--------

This utility is used to backup an Oracle database. If the database to be backed
up is not started, it will be started in order to determine the list of files
that are to be backed up. The database will be left in whatever state it was in
before the command started.

Arguments
=========

+---------------------+-------------------------------------------------------+
| Name                | Description                                           |
+---------------------+-------------------------------------------------------+
| SID                 | the SID of the database to backup                     |
+---------------------+-------------------------------------------------------+
| FILENAME            | the name of the file or directory in which to place   |
|                     | the backed up files (see `Backup Files`_)             |
+---------------------+-------------------------------------------------------+

Options
=======

+---------------------+-------------------------------------------------------+
| Name                | Description                                           |
+---------------------+-------------------------------------------------------+
| -t, --traceback     | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --show-banner       | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --version           | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| -h, --help          | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --config-file-name= | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --sys-password=     | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --tnsentry=         | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --no-start          | do not start the database if it is not already        |
|                     | started                                               |
+---------------------+-------------------------------------------------------+
| --offline           | perform an offline backup (the database is shut       |
|                     | down); this is the only option if the database is not |
|                     | in archivelog mode                                    |
+---------------------+-------------------------------------------------------+
| --log-file=         | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --log-level=        | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --log-prefix=       | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+


-------
CloneDB
-------

This utility is used to make a copy of an Oracle database. If the database to
be cloned is not started, it will be started in order to determine the list of
files that are to be copied. The database will be left in whatever state it was
in before the command started.

Arguments
=========

+---------------------+-------------------------------------------------------+
| Name                | Description                                           |
+---------------------+-------------------------------------------------------+
| ORIGSID             | the SID of the database to clone                      |
+---------------------+-------------------------------------------------------+
| NEWSID              | the SID of the database to create                     |
+---------------------+-------------------------------------------------------+

Options
=======

+---------------------+-------------------------------------------------------+
| Name                | Description                                           |
+---------------------+-------------------------------------------------------+
| -t, --traceback     | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --show-banner       | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --version           | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| -h, --help          | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --config-file-name= | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --sys-password=     | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --tnsentry=         | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --no-prompts        | do not issue any prompts and accept all defaults      |
+---------------------+-------------------------------------------------------+
| --replace-existing  | if a database with ``NEWSID`` already exists, it will |
|                     | be removed first                                      |
+---------------------+-------------------------------------------------------+
| --no-start          | do not start the database if it is not already        |
|                     | started                                               |
+---------------------+-------------------------------------------------------+
| --offline           | perform an offline copy (the database to clone is     |
|                     | shut down); this is the only option if the database   |
|                     | to clone is not in archivelog mode                    |
+---------------------+-------------------------------------------------------+
| --log-file=         | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --log-level=        | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --log-prefix=       | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+


--------
CreateDB
--------

This utility is used to create an Oracle database. When this utility is run,
the following steps are performed:

    - the directories mentioned in the directory template file are created
    - the parameter file is created based on the parameter template file
    - a link to the parameter file is created in <ORACLE_HOME>/dbs (Unix) or
      <ORACLE_HOME>/database (Windows)
    - a service is created (Windows only)
    - the creation script is run in SQL*Plus

**NOTE:** This utility does not update any Oracle networking configuration
(i.e. listener.ora, tnsnames.ora)

Arguments
=========

+---------------------+-------------------------------------------------------+
| Name                | Description                                           |
+---------------------+-------------------------------------------------------+
| SID                 | the SID of the database to create                     |
+---------------------+-------------------------------------------------------+
| SUBSITUTIONS        | any number of name=value pairs which are used for     |
|                     | additional substitutions in the template files        |
|                     | described in the Configuration_ section               |
+---------------------+-------------------------------------------------------+

Options
=======

+---------------------+-------------------------------------------------------+
| Name                | Description                                           |
+---------------------+-------------------------------------------------------+
| -t, --traceback     | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --show-banner       | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --version           | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| -h, --help          | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --config-file-name= | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --type=             | the type of database to create; the default value is  |
|                     | specified in the Configuration_ file.                 |
+---------------------+-------------------------------------------------------+
| --start-mode=       | specifies the mode of database startup; valid values  |
|                     | are ``Manual`` and ``Auto``; the default value is     |
|                     | ``Auto``; this value is used by StartDB_ to determine |
|                     | which databases to start when the --all-auto option   |
|                     | is specified                                          |
+---------------------+-------------------------------------------------------+
| --sys-password=     | the password to use for the sys account; the default  |
|                     | value is the name of the machine on which the         |
|                     | database is being created                             |
+---------------------+-------------------------------------------------------+
| --tnsentry=         | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --log-file=         | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --log-level=        | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --log-prefix=       | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+


-----------------
ExportControlFile
-----------------

This utility is used to export the control file for the database in the same
format as the output from the command
``alter database backup controlfile to trace;``

Arguments
=========

+---------------------+-------------------------------------------------------+
| Name                | Description                                           |
+---------------------+-------------------------------------------------------+
| SID                 | the SID of the database for which to export the       |
|                     | control file                                          |
+---------------------+-------------------------------------------------------+
| [FILENAME]          | the name of the file to which to write the control    |
|                     | file; if unspecified this will go to stdout           |
+---------------------+-------------------------------------------------------+

Options
=======

+---------------------+-------------------------------------------------------+
| Name                | Description                                           |
+---------------------+-------------------------------------------------------+
| -t, --traceback     | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --show-banner       | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --version           | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| -h, --help          | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --config-file-name= | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --sys-password=     | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --tnsentry=         | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --log-file=         | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --log-level=        | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --log-prefix=       | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+


--------------------
ExportParameterFile
--------------------

This utility is used to export the parameter file for the database in the
format required by Oracle.

Arguments
=========

+---------------------+-------------------------------------------------------+
| Name                | Description                                           |
+---------------------+-------------------------------------------------------+
| SID                 | the SID of the database for which to export the       |
|                     | parameter file                                        |
+---------------------+-------------------------------------------------------+
| [FILENAME]          | the name of the file to which to write the parameter  |
|                     | file; if unspecified this will go to stdout           |
+---------------------+-------------------------------------------------------+

Options
=======

+---------------------+-------------------------------------------------------+
| Name                | Description                                           |
+---------------------+-------------------------------------------------------+
| -t, --traceback     | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --show-banner       | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --version           | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| -h, --help          | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --config-file-name= | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --sys-password=     | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --tnsentry=         | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --log-file=         | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --log-level=        | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --log-prefix=       | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+


--------
RemoveDB
--------

This utility is used to remove one or more Oracle databases from the system.

Arguments
=========

+---------------------+-------------------------------------------------------+
| Name                | Description                                           |
+---------------------+-------------------------------------------------------+
| SIDS                | the SID(s) of the databases to remove, separated by   |
|                     | commas                                                |
+---------------------+-------------------------------------------------------+

Options
=======

+---------------------+-------------------------------------------------------+
| Name                | Description                                           |
+---------------------+-------------------------------------------------------+
| -t, --traceback     | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --show-banner       | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --version           | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| -h, --help          | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --config-file-name= | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --sys-password=     | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --tnsentry=         | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --ignore-if-missing | do not issue an error if the database does not exist  |
|                     | when attempting to remove it                          |
+---------------------+-------------------------------------------------------+
| --log-file=         | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --log-level=        | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --log-prefix=       | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+


---------
RestoreDB
---------

This utility is used to restore an Oracle database from a backup file or
directory created with BackupDB_.

Arguments
=========

+---------------------+-------------------------------------------------------+
| Name                | Description                                           |
+---------------------+-------------------------------------------------------+
| FILENAME            | the name of the file or directory from which to       |
|                     | restore the database (see `Backup Files`_)            |
+---------------------+-------------------------------------------------------+

Options
=======

+---------------------+-------------------------------------------------------+
| Name                | Description                                           |
+---------------------+-------------------------------------------------------+
| -t, --traceback     | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --show-banner       | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --version           | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| -h, --help          | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --config-file-name= | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --no-prompts        | do not issue any prompts and accept all defaults      |
+---------------------+-------------------------------------------------------+
| --replace-existing  | if a database with the SID being restored already     |
|                     | exists, it will be removed first                      |
+---------------------+-------------------------------------------------------+
| --sys-password=     | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --tnsentry=         | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --as-sid=           | restore the database as this SID rather than the one  |
|                     | specified in the backup file or directory             |
+---------------------+-------------------------------------------------------+
| --log-file=         | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --log-level=        | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --log-prefix=       | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+


-------
StartDB
-------

This utility is used to start one or more Oracle databases. On Windows the
Oracle home is determined by looking at the service created for the database.
On Unix this is determined by looking at the environment configuration file
(ADMIN_DIR/config/env.cfg). The database is then started using that Oracle
home.

Arguments
=========

+---------------------+-------------------------------------------------------+
| Name                | Description                                           |
+---------------------+-------------------------------------------------------+
| SIDS                | the SID(s) of the databases to start, separated by    |
|                     | commas                                                |
+---------------------+-------------------------------------------------------+

Options
=======

+---------------------+-------------------------------------------------------+
| Name                | Description                                           |
+---------------------+-------------------------------------------------------+
| -t, --traceback     | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --show-banner       | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --version           | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| -h, --help          | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --config-file-name= | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --sys-password=     | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --tnsentry=         | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| -r, --restart       | if any of the databases being started is already      |
|                     | started, shut it down and then start it up again      |
+---------------------+-------------------------------------------------------+
| --shutdown-mode=    | the mode used to shutdown any databases if the        |
|                     | --restart option is specified; this must be one of    |
|                     | ``immediate`` or ``abort`` with the default being     |
|                     | ``immediate``                                         |
+---------------------+-------------------------------------------------------+
| --all               | start all of the databases on this machine; this list |
|                     | is determined by looking at the services on Windows   |
|                     | and by scanning the directories under ADMIN_DIR on    |
|                     | other platforms                                       |
+---------------------+-------------------------------------------------------+
| --all-auto          | this is identical to --all except that only those     |
|                     | databases configured to start automatically will be   |
|                     | started                                               |
+---------------------+-------------------------------------------------------+
| --log-file=         | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --log-level=        | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --log-prefix=       | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+


------
StopDB
------

This utility is used to stop one or more Oracle databases. On Windows the
Oracle home is determined by looking at the service created for the database.
On Unix this is determined by looking at the environment configuration file
(ADMIN_DIR/config/env.cfg). The database is then stopped using that Oracle
home.

Arguments
=========

+---------------------+-------------------------------------------------------+
| Name                | Description                                           |
+---------------------+-------------------------------------------------------+
| SIDS                | the SID(s) of the databases to stop, separated by     |
|                     | commas                                                |
+---------------------+-------------------------------------------------------+

Options
=======

+---------------------+-------------------------------------------------------+
| Name                | Description                                           |
+---------------------+-------------------------------------------------------+
| -t, --traceback     | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --show-banner       | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --version           | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| -h, --help          | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --config-file-name= | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --sys-password=     | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --tnsentry=         | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --shutdown-mode=    | the mode used to shutdown the databases; this must be |
|                     | one of ``immediate`` or ``abort`` with the default    |
|                     | being ``immediate``                                   |
+---------------------+-------------------------------------------------------+
| --all               | stop all of the databases on this machine; this list  |
|                     | is determined by looking at the services on Windows   |
|                     | and by scanning the directories under ADMIN_DIR on    |
|                     | other platforms                                       |
+---------------------+-------------------------------------------------------+
| --log-file=         | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --log-level=        | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+
| --log-prefix=       | see `Common Options`_                                 |
+---------------------+-------------------------------------------------------+

