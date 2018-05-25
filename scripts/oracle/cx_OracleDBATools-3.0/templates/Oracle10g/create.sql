spool %(ADMIN_DIR)s/scripts/create.log
startup nomount
create database %(SID)s
    maxinstances 1
    datafile '%(BASE_DIR)s/data/%(SID)s/system_01.dbf' size 250m
    sysaux datafile '%(BASE_DIR)s/data/%(SID)s/sysaux_01.dbf' size 100m
    extent management local
    undo tablespace undo 
            datafile '%(BASE_DIR)s/data/%(SID)s/undo_01.dbf' size 40m
    default temporary tablespace temp
            tempfile '%(BASE_DIR)s/data/%(SID)s/temp_01.dbf' size 40m
            extent management local uniform size 1m
    logfile '%(BASE_DIR)s/data/%(SID)s/log_01.dbf' size 10m,
            '%(BASE_DIR)s/data/%(SID)s/log_02.dbf' size 10m,
            '%(BASE_DIR)s/data/%(SID)s/log_03.dbf' size 10m
    user sys identified by "%(SYS_PW)s"
    user system identified by "%(SYS_PW)s";
whenever sqlerror continue
@%(ORACLE_HOME)s/rdbms/admin/catalog
@%(ORACLE_HOME)s/rdbms/admin/catproc
@%(ORACLE_HOME)s/rdbms/admin/catblock
@%(ORACLE_HOME)s/rdbms/admin/caths
@%(ORACLE_HOME)s/rdbms/admin/dbmspool
@%(ORACLE_HOME)s/rdbms/admin/dbmsrand
@%(ORACLE_HOME)s/rdbms/admin/otrcsvr
connect system/%(SYS_PW)s
@%(ORACLE_HOME)s/sqlplus/admin/pupbld
spool off
