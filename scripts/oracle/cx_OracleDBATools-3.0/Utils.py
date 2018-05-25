"""
Define utility functions.
"""

import cx_ReadLine
import os

class Mapping(object):

    def __init__(self, database, origDatabase, prompts):
        self.dirMapping = {}
        dir = NormalizePath(origDatabase.adminDir)
        self.dirMapping[dir] = database.adminDir
        if database.oracleHome != origDatabase.oracleHome:
            dir = NormalizePath(origDatabase.oracleHome)
            self.dirMapping[dir] = database.oracleHome
        self.fileMapping = {}
        self.fileMapping[origDatabase.storedParameterFileName] = \
                database.storedParameterFileName
        self.fileMapping[origDatabase.passwordFileName] = \
                database.passwordFileName
        self.__PopulateDirMapping(database, origDatabase, prompts)

    def __PopulateDirMapping(self, database, origDatabase, prompts):
        """Populate the directory mapping by taking all of the directories
           from the original database and creating a mapping for each one."""
        origSid = NormalizePath(origDatabase.sid)
        temp = [(len(n), n) for n in origDatabase.GetDirectories()]
        temp.sort()
        dirs = [n for s, n in temp]
        for dir in dirs:
            dir = NormalizePath(dir)
            if dir in self.dirMapping:
                continue
            defaultDir = self.MappedDir(dir)
            if defaultDir == dir:
                defaultDir = dir.replace(origSid, database.sid)
            if prompts:
                newDir = cx_ReadLine.ReadLine("Map %s to" % dir, defaultDir)
            else:
                newDir = defaultDir
            self.dirMapping[dir] = newDir

    def MappedDir(self, name):
        """Return the directory to use given the original directory."""
        rightPart = ""
        name = leftPart = NormalizePath(name)
        while True:
            if leftPart in self.dirMapping:
                leftPart = self.dirMapping[leftPart]
                return NormalizePath(os.path.join(leftPart, rightPart))
            leftPart, remainder = os.path.split(leftPart)
            if not remainder:
                break
            rightPart = NormalizePath(os.path.join(remainder, rightPart))
        return name

    def MappedFileName(self, name):
        """Return the file name to use given the original file name."""
        if name in self.fileMapping:
            return self.fileMapping[name]
        dir, name = os.path.split(name)
        dir = self.MappedDir(dir)
        return NormalizePath(os.path.join(dir, name))


def NormalizePath(name):
    """Normalize a file name so that it compares identically to another file
       name even if the exact string contents differ; this is needed since on
       Windows files are stored irrespective of case and it supports both the
       forward slash and the backward slash for separating path components."""
    return os.path.normcase(os.path.normpath(name))


class RecoveryManagerSession(object):

    def __init__(self):
        self.inputLines = []

    def AddCommand(self, format, *args):
        command = format % args
        self.inputLines.append(command + ";")

    def AddSqlCommand(self, sql):
        self.AddCommand('sql "%s"', sql.replace("'", "''"))

