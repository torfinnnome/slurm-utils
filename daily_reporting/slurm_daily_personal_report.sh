#!/bin/bash

# (c) CIGENE, Torfinn Nome, 2015-02

PATH=/local/genome/packages/slurm/14.03.3-2/bin:$PATH

# Get all jobs finished by user ($1) completed between $2 and $3. Only fetch the 100 oldest jobs.
JOBS=$(sacct -u $1 --starttime $2 --endtime $3 --state=COMPLETED|awk ' ($2 != "batch") && ($2 != "probejob")'|grep COMPLETED|head -100l|awk ' { printf "%s ", $1; }')

seconds2time ()
{
   # http://unix.stackexchange.com/questions/27013/displaying-seconds-as-days-hours-mins-seconds
   T=$1
   D=$((T/60/60/24))
   H=$((T/60/60%24))
   M=$((T/60%60))
   S=$((T%60))

   if [[ ${D} != 0 ]]
   then
      printf '%d days %02d:%02d:%02d' $D $H $M $S
   else
      printf '%02d:%02d:%02d' $H $M $S
   fi
}

slurmdate2sec() {
  # http://stackoverflow.com/questions/14652445/parse-ps-etime-output-into-seconds
  local time_string="$1"
  local time_string_array=()
  local time_seconds=0
  local return_status=0

  [[ -z "${time_string}" ]] && return 255

  # etime string returned by ps(1) consists one of three formats:
  #         31:24 (less than 1 hour)
  #      23:22:38 (less than 1 day)
  #   01-00:54:47 (more than 1 day)
  #

  # convert days component into just another element
  time_string="${time_string//-/:}"

  # split time_string into components separated by ':'
  time_string_array=( ${time_string//:/ } )

  # parse the array in reverse (smallest unit to largest)
  local _elem=""
  local _indx=1
  for(( i=${#time_string_array[@]}; i>0; i-- )); do
    _elem="${time_string_array[$i-1]}"
    case ${_indx} in
      1 )
        # Fix by Torfinn: Strip leading zeros:
        (( time_seconds+=${_elem#0} ))
        ;;
      2 )
        (( time_seconds+=${_elem#0}*60 ))
        ;;
      3 )
        (( time_seconds+=${_elem#0}*3600 ))
        ;;
      4 )
        (( time_seconds+=${_elem#0}*86400 ))
        ;;
    esac
    (( _indx++ ))
  done
  unset _indx
  unset _elem

  echo "$time_seconds"
  #; return $return_status
}

# Include a static header:
cat /mnt/various/slurm/bin/slurm_daily_personal_report.header.txt

for SLURM_JOB_ID in $JOBS;
do
  # Lazy, inefficient way, but it works, for now:
  ncpus=$(sacct --noheader --format=NCPUS -j $SLURM_JOB_ID | head -1l |  awk ' { print $1; }')
  elapsed=$(sacct --noheader --format=elapsed -j $SLURM_JOB_ID | head -1l |  awk ' { print $1; }'  | sed 's/+/00/g')
  totalcpu=$(sacct --noheader --format=totalcpu -j $SLURM_JOB_ID | head -1l |  awk ' { print $1; }' | sed 's/+/00/g')

  # Strip away trailing microseconds of totalcpu:
  totalcpu=$(echo $totalcpu | sed 's/\..*//g')

  elapsedSec=$(slurmdate2sec $elapsed)
  totalcpuSec=$(slurmdate2sec $totalcpu)

  # Don't view jobs using less than 5 CPU minutes:
  if [ $totalcpuSec -gt $((60 * 5)) ];
  then
	        # Append job information:
                sacct --format=JobID,JobName,NCPUS,NNodes,Elapsed,TotalCPU,ReqMem,MaxRSS,NodeList -j $SLURM_JOB_ID | awk ' { print "#", $0; }'

		# Calculate used CPUs:
		requestedSec=$(($elapsedSec * $ncpus))

		echo "#"
		echo -n "# You requested CPU time: "
		seconds2time $requestedSec
		echo ""
		echo -n "# You actually used CPU time: "
		seconds2time $totalcpuSec
		echo ""
		
		# Calculate CPU efficiency:
		cpuEff=$(echo "($totalcpuSec / $requestedSec) * 100" | bc -l)
		cpuEff=$(printf "%0.f" $cpuEff)

		echo "# CPU efficiency (%): $cpuEff"
		if [ $ncpus -gt 1 ];
		then
		  if [ $cpuEff -gt 110 ];
		  then
		    echo "# You might want to request more CPUs. (Increase --ntasks or -n.)"
		  fi
		  if [ $cpuEff -lt 70 ];
		  then
		    echo "# You might want to request less CPUs. (Decrease --ntasks or -n.)"
		  fi
		fi
            echo "<br>"
  fi
done
