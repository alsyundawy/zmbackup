#!/bin/bash
################################################################################
# Session List Functions
################################################################################

################################################################################
# list_sessions: Just call the correct function based on $SESSION_TYPE
################################################################################
function list_sessions()
{
  if [[ $SESSION_TYPE == 'TXT' ]]; then
    list_sessions_txt
  elif [[ $SESSION_TYPE == "SQLITE3" ]]; then
    list_sessions_sqlite3
  else
    echo "Invalid File Format - Nothing to do."
  fi
}

################################################################################
# list_sessions_txt: List all the sessions stored inside the server - TXT
################################################################################
function list_sessions_txt ()
{
  printf "+---------------------------+------------+----------+----------------------------+\n"
  printf "|       Session Name        |    Date    |   Size   |        Description         |\n"
  printf "+---------------------------+------------+----------+----------------------------+\n"
  for i in $(grep -E 'SESSION:' "$WORKDIR"/sessions.txt | grep 'started' |  awk '{print $2}' | sort | uniq); do

    # Load variables
    SIZE=$(du -h "$WORKDIR"/"$i" | awk '{print $1}')
    OPT=$(echo "$i" | cut -d"-" -f1 )
    parse_session_name "$i"
    case $OPT in
      "full")      OPT="Full Backup" ;;
      "inc")       OPT="Incremental Backup" ;;
      "distlist")  OPT="Distribution List Backup" ;;
      "alias")     OPT="Alias Backup" ;;
      "ldap")      OPT="Account Backup - Only LDAP" ;;
      "mbox")      OPT="Mailbox Backup" ;;
      "signature") OPT="Signature Backup" ;;
    esac

    # Printing the information as a table
    # shellcheck disable=SC2153
    printf "| %-25s | %s/%s/%s | %-8s | %-26s |\n" "$i" "$MONTH" "$DAY" "$YEAR" "$SIZE" "$OPT"
  done
  printf "+---------------------------+------------+----------+----------------------------+\n"
}

################################################################################
# list_sessions_sqlite3: List all the sessions stored inside the server - SQLITE3
################################################################################
function list_sessions_sqlite3 ()
{
  printf "+---------------------------+--------------+--------------+----------+----------------------------+\n"
  printf "|       Session Name        |    Start     |    Ending    |   Size   |        Description         |\n"
  printf "+---------------------------+--------------+--------------+----------+----------------------------+\n"
  sqlite3 "$WORKDIR"/sessions.sqlite3 'select * from backup_session' | while read -r i ; do
    NAME=$(echo "$i" | cut -d'|' -f1)
    SMONTH=$(echo "$i" | cut -d'|' -f2 | cut -d'-' -f2)
    SDAY=$(echo "$i" | cut -d'|' -f2 | cut -d'-' -f3 | cut -d'T' -f1)
    SYEAR=$(echo "$i" | cut -d'|' -f2 | cut -d'-' -f1)
    EMONTH=$(echo "$i" | cut -d'|' -f3 | cut -d'-' -f2)
    EDAY=$(echo "$i" | cut -d'|' -f3 | cut -d'-' -f3 | cut -d'T' -f1)
    EYEAR=$(echo "$i" | cut -d'|' -f3 | cut -d'-' -f1)
    SIZE=$(echo "$i" | cut -d'|' -f4)
    OPT=$(echo "$i" | cut -d'|' -f5)
    printf "| %-25s |  %s/%s/%s  |  %s/%s/%s  | %-8s | %-26s |\n" "$NAME" "$SMONTH" "$SDAY" "$SYEAR" "$EMONTH" "$EDAY" "$EYEAR" "$SIZE" "$OPT"
  done
  printf "+---------------------------+--------------+--------------+----------+----------------------------+\n"
}
