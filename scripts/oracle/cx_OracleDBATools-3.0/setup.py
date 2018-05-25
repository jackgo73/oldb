import distutils.log
import distutils.errors
import cx_Freeze
import os
import sys

if sys.platform != "win32":
    dataFiles = []
else:
    dataFiles = [ ("", [ "LICENSE.TXT", "README.TXT", "HISTORY.txt"] ) ]
    for path, dirNames, fileNames in os.walk("templates"):
        fileNames = [os.path.join(path, n) for n in fileNames]
        dataFiles.append((path, fileNames))
        if ".svn" in dirNames:
            dirNames.remove(".svn")

class build_exe(cx_Freeze.build_exe):
    user_options = cx_Freeze.build_exe.user_options + [
            ('cx-logging=', None, 'location of cx_Logging sources'),
            ('cx-oracle=', None, 'location of cx_Oracle sources'),
            ('cx-pygenlib=', None, 'location of cx_PyGenLib sources'),
            ('oracle-homes=', None, 'comma separated list of Oracle homes')
    ]


    def _set_oracle_homes(self):
        envName = "ORACLE_HOMES"
        oracleHomes = self.oracle_homes
        if oracleHomes is None:
            oracleHomes = os.environ.get(envName)
            if oracleHomes is not None:
                oracleHomes = oracleHomes.split(",")
        if oracleHomes is None:
            oracleHome = os.environ.get("ORACLE_HOME")
            if oracleHome is None:
                if sys.platform == "win32":
                    fileNameToFind = "oci.dll"
                else:
                    fileNameToFind = "oracle"
                for path in os.environ["PATH"].split(os.pathsep):
                    if os.path.exists(os.path.join(path, fileNameToFind)):
                        oracleHome = os.path.dirname(path)
                        break
            if oracleHome is None:
                message = "cannot locate an Oracle software installation"
                raise distutils.errors.DistutilsSetupError(message)
            oracleHomes = [oracleHome]
        self.oracle_homes = oracleHomes
        os.environ[envName] = ",".join(oracleHomes)

    def initialize_options(self):
        cx_Freeze.build_exe.initialize_options(self)
        self.cx_logging = None
        self.cx_oracle = None
        self.cx_pygenlib = None
        self.oracle_homes = None

    def finalize_options(self):
        cx_Freeze.build_exe.finalize_options(self)
        self.set_source_location("cx_Logging", "tags", "2.0")
        self.set_source_location("cx_Oracle", "tags", "5.0.4")
        self.set_source_location("cx_PyGenLib", "tags", "3.0")
        if self.cx_oracle is None:
            message = "cannot locate a cx_Oracle software installation"
            raise distutils.errors.DistutilsSetupError(message)
        self._set_oracle_homes()

    def run(self):
        self.build_extension("cx_Logging")
        for oracleHome in self.oracle_homes:
            distutils.log.info("building cx_Oracle in home '%s'" % oracleHome)
            os.environ["ORACLE_HOME"] = oracleHome
            sourceFileName = self.build_extension("cx_Oracle")
            dirName = os.path.dirname(sourceFileName)
            oracleVersion = dirName.split("-")[-1]
            baseFileName, ext = os.path.splitext(sourceFileName)
            targetFileName = os.path.join(self.build_exe,
                    "cx_Oracle_%s%s" % (oracleVersion, ext))
            dirName = os.path.dirname(targetFileName)
            if not os.path.isdir(dirName):
                os.makedirs(dirName)
            self.copy_file(sourceFileName, targetFileName)
        self.add_to_path("cx_PyGenLib")
        cx_Freeze.build_exe.run(self)

executables = [
        cx_Freeze.Executable("BackupDB.py"),
        cx_Freeze.Executable("CloneDB.py"),
        cx_Freeze.Executable("CreateDB.py"),
        cx_Freeze.Executable("ExportControlFile.py"),
        cx_Freeze.Executable("ExportParameterFile.py"),
        cx_Freeze.Executable("RemoveDB.py"),
        cx_Freeze.Executable("RestoreDB.py"),
        cx_Freeze.Executable("StartDB.py"),
        cx_Freeze.Executable("StopDB.py")
]
if sys.platform == "linux2":
    executables.append(cx_Freeze.Executable("ShowMemoryDB.py"))

buildOptions = dict(
        compressed = True,
        includes = ["datetime", "decimal"],
        optimize = 2,
        replace_paths = [("*", "")])
docFiles = "LICENSE.txt README.txt HISTORY.txt doc/cx_OracleDBATools.html " \
        "templates"
rpmOptions = dict(
        doc_files = docFiles)
msiOptions = dict(
        upgrade_code = "{595A8830-7B31-4BE3-BDDA-979CFADF06A1}")

cx_Freeze.setup(
        name = "cx_OracleDBATools",
        version = "3.0",
        description = "Tools for managing Oracle databases",
        long_description = "Tools for managing Oracle databases",
        maintainer = "Anthony Tuininga",
        maintainer_email = "anthony.tuininga@gmail.com",
        url = "http://cx-oradbatools.sourceforge.net",
        data_files = dataFiles,
        cmdclass = dict(build_exe = build_exe),
        executables = executables,
        options = dict(build_exe = buildOptions, bdist_msi = msiOptions,
                bdist_rpm = rpmOptions))

