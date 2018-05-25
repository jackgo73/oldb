"""
Shows the memory used by the database.
"""

import cx_LoggingOptions
import cx_OptionParser
import os

# parse command line
parser = cx_OptionParser.OptionParser("ShowMemoryDB")
cx_LoggingOptions.AddOptions(parser)
parser.AddArgument("sid", required = True,
        help = "the SID of the database for which memory usage will be shown")
options = parser.Parse()
cx_LoggingOptions.ProcessOptions(options)

# define method that returns a list of pids
def GetPids(mask):
    pids = []
    for line in os.popen("ps -ef | grep %s | grep -v grep" % mask):
        parts = line.strip().split()
        pids.append(int(parts[1]))
    return pids

# define method that returns the formatted size in KB or MB
def FormattedSize(size):
    size = size / 1024
    if size > 9999:
        return "%d MB" % (size / 1024)
    return "%d KB" % size

# define method that returns the memory used by a set of processes
def ShowMemoryUsage(header, mask):
    mapped = 0
    shared = 0
    private = 0
    pids = GetPids(mask)
    for pid in pids:
        for line in file("/proc/%d/maps" % pid):
            parts = line.strip().split()
            startAddr, endAddr = parts[0].split("-")
            size = int(endAddr, 16) - int(startAddr, 16)
            flags = parts[1]
            if flags[-1] == "s":
                shared += size
            elif flags[:3] == "r-x":
                mapped += size
            else:
                private += size
    print("%s (%d processes):" % (header, len(pids)))
    print("    Private: %s" % FormattedSize(private))
    print("    Mapped: %s" % FormattedSize(mapped))
    print("    Shared: %s" % FormattedSize(shared))

# locate the pids of the shadow processes
ShowMemoryUsage("Background Processes", "ora_.\*_%s" % options.sid)
ShowMemoryUsage("Client Processes", "oracle%s" % options.sid)

