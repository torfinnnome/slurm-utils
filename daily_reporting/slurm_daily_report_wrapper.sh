#!/bin/bash

# (c) CIGENE, Torfinn Nome, 2015-02

#
# Run this script one a day, to send daily slurm reports.
#
# Add something like this to crontab
# 15 0 * * * /bin/bash /mnt/various/slurm/bin/slurm_daily_report_wrapper.sh
#

source /mnt/various/profile/cigene.sh

PREFIX=/mnt/various/slurm

YESTERDAY=$(date --date "yesterday" +%Y-%m-%d)
TODAY=$(date +%Y-%m-%d)

# Get list of users whith jobs that finished yesterday.
USERS=$(sacct --noheader -a --format=JobID,JobName%20,User%20,Partition,Account,AllocCPUS,State,ExitCode  --starttime $YESTERDAY --endtime $TODAY --state=COMPLETED|awk ' ($2 != "batch") && ($2 != "probejob")' |awk ' { print $3; }'|egrep -v 'root|galaxy' | sort|uniq |awk ' { printf "%s ", $1; }')
OUTDIR=$PREFIX/usage-reports/$YESTERDAY

HEADER=$PREFIX/bin/slurm_daily_personal_report.header.txt
HEADERSIZE=$(stat -c%s "$HEADER")

mkdir $OUTDIR

for USER in $USERS;
do
  REPORT=$OUTDIR/${USER}.txt
  
  # Generate the report:
  bash $PREFIX/bin/slurm_daily_personal_report.sh $USER $YESTERDAY $TODAY > $REPORT
  REPORTSIZE=$(stat -c%s "$REPORT")
  
  # Only send report by email if we actually added content to it:
  if [ $REPORTSIZE -gt $HEADERSIZE ];
  then
    echo "Sending email to $USER"
    mutt -e 'my_hdr From:Orion Cluster <noreply@orion.nmbu.no>' -e 'set content_type="text/html"' -s "Daily Orion usage report: $USER $YESTERDAY" ${USER}@localhost < $REPORT
  fi
done
