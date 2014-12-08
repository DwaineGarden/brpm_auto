#
# Action to run sql file via Oracle's sqlplus
#
# REQUIRED VARIABLES
#   ORACLE_HOME
#   ORACLE_USERNAME
#   ORACLE_PASSWORD
#   ORACLE_SID

# NOTE:  Returning proper exit codes from the provided sql file must be done to
#   ensure that the action will exit with success or failure of the sql commands
#   being run.  For example:

# WHENEVER SQLERROR EXIT SQL.SQLCODE
#   begin
#     SELECT COLUMN_DOES_NOT_EXIST FROM DUAL;
#   END;
export ORACLE_HOME

SQLPLUS="sqlplus"
if [ ! -z "$ORACLE_HOME" ]
then
    SQLPLUS="$ORACLE_HOME/bin/sqlplus"
fi

TMPFILE=file$RANDOM.sql
ln -s $RPM_PAYLOAD $TMPFILE


echo "echo quit | $SQLPLUS -L -s $ORACLE_USERNAME/-------@$ORACLE_SID @$TMPFILE"
echo quit | (($SQLPLUS -L -s $ORACLE_USERNAME/$ORACLE_PASSWORD@$ORACLE_SID @$TMPFILE) && unlink $TMPFILE)

exit $?

