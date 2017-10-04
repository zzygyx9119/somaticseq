#!/bin/bash
# Use getopt instead of getopts for long options

set -e

OPTS=`getopt -o o: --long out-dir:,out-vcf:,in-bam:,human-reference:,selector:,dbsnp:,action: -n 'submit_LoFreq.sh'  -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

#echo "$OPTS"
eval set -- "$OPTS"

MYDIR="$( cd "$( dirname "$0" )" && pwd )"

timestamp=$( date +"%Y-%m-%d_%H-%M-%S_%N" )
VAF=0.05
action=echo

while true; do
    case "$1" in
    --out-vcf )
        case "$2" in
            "") shift 2 ;;
            *)  outvcf=$2 ; shift 2 ;;
        esac ;;

    --out-dir )
        case "$2" in
            "") shift 2 ;;
            *)  outdir=$2 ; shift 2 ;;
        esac ;;

    --in-bam )
        case "$2" in
            "") shift 2 ;;
            *)  tumor_bam=$2 ; shift 2 ;;
        esac ;;

    --human-reference )
        case "$2" in
            "") shift 2 ;;
            *)  HUMAN_REFERENCE=$2 ; shift 2 ;;
        esac ;;

    --selector )
        case "$2" in
            "") shift 2 ;;
            *) SELECTOR=$2 ; shift 2 ;;
        esac ;;

    --dbsnp )
        case "$2" in
            "") shift 2 ;;
            *) dbsnp=$2 ; shift 2 ;;
        esac ;;

    --action )
        case "$2" in
            "") shift 2 ;;
            *) action=$2 ; shift 2 ;;
        esac ;;

    -- ) shift; break ;;
    * ) break ;;
    esac

done

vcf_prefix=${outvcf%\vcf}

logdir=${outdir}/logs
mkdir -p ${logdir}

lofreq_script=${outdir}/logs/lofreq_${timestamp}.cmd

echo "#!/bin/bash" > $lofreq_script
echo "" >> $lofreq_script

echo "#$ -o ${logdir}" >> $lofreq_script
echo "#$ -e ${logdir}" >> $lofreq_script
echo "#$ -S /bin/bash" >> $lofreq_script
echo '#$ -l h_vmem=12G' >> $lofreq_script
echo 'set -e' >> $lofreq_script
echo "" >> $lofreq_script

echo 'echo -e "Start at `date +"%Y/%m/%d %H:%M:%S"`" 1>&2' >> $lofreq_script
echo "" >> $lofreq_script

echo "docker run --rm -v /:/mnt -u $UID --memory 12g lethalfang/lofreq:2.1.3.1 \\" >> $lofreq_script
echo "lofreq call \\" >> $lofreq_script
echo "--call-indels \\" >> $lofreq_script
echo "--min-mq 1 \\" >> $lofreq_script
echo "-l /mnt/${SELECTOR} \\" >> $lofreq_script
echo "-f /mnt/${HUMAN_REFERENCE} \\" >> $lofreq_script
echo "-o /mnt/${outdir}/${outvcf} \\" >> $lofreq_script
echo "-S /mnt/${dbsnp}.gz \\" >> $lofreq_script
echo "/mnt/${tumor_bam}" >> $lofreq_script

echo "" >> $lofreq_script
echo 'echo -e "Done at `date +"%Y/%m/%d %H:%M:%S"`" 1>&2' >> $lofreq_script

${action} $lofreq_script
