#!/bin/bash
# Use getopt instead of getopts for long options

set -e

OPTS=`getopt -o o: --long out-dir:,out-vcf:,in-bam:,human-reference:,selector:,action:,VAF: -n 'submit_VarDictJava.sh'  -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

#echo "$OPTS"
eval set -- "$OPTS"

MYDIR="$( cd "$( dirname "$0" )" && pwd )"

timestamp=$( date +"%Y-%m-%d_%H-%M-%S_%N" )
VAF=0.05
action=echo
MEM='8G'

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

    --VAF )
        case "$2" in
            "") shift 2 ;;
            *) VAF=$2 ; shift 2 ;;
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

VERSION=`cat ${MYDIR}/../../../VERSION | sed 's/##SomaticSeq=v//'`

logdir=${outdir}/logs
mkdir -p ${logdir}

vardict_script=${outdir}/logs/vardict_${timestamp}.cmd

echo "#!/bin/bash" > $vardict_script
echo "" >> $vardict_script

echo "#$ -o ${logdir}" >> $vardict_script
echo "#$ -e ${logdir}" >> $vardict_script
echo "#$ -S /bin/bash" >> $vardict_script
echo "#$ -l h_vmem=${MEM}" >> $vardict_script
echo 'set -e' >> $vardict_script
echo "" >> $vardict_script

echo 'echo -e "Start at `date +"%Y/%m/%d %H:%M:%S"`" 1>&2' >> $vardict_script
echo "" >> $vardict_script


total_bases=`cat ${SELECTOR} | awk -F "\t" '{print $3-$2}' | awk '{ sum += $1 } END { print sum }'`
num_lines=`cat ${SELECTOR} | wc -l`

input_bed=${SELECTOR}
if [[ $(( $total_bases / $num_lines )) -gt 50000 ]]
then
    echo "docker run --rm -v /:/mnt -u $UID --memory ${MEM} lethalfang/somaticseq:${VERSION} \\" >> $vardict_script
    echo "/opt/somaticseq/utilities/split_mergedBed.py \\" >> $vardict_script
    echo "-infile /mnt/${SELECTOR} -outfile /mnt/${outdir}/split_regions.bed" >> $vardict_script
    echo "" >> $vardict_script
    
    input_bed="${outdir}/split_regions.bed"
fi


echo "docker run --rm -v /:/mnt -u $UID --memory ${MEM} lethalfang/vardictjava:1.5.1 bash -c \\" >> $vardict_script
echo "\"/opt/VarDict-1.5.1/bin/VarDict \\" >> $vardict_script
echo "-G /mnt/${HUMAN_REFERENCE} \\" >> $vardict_script
echo "-f $VAF -h \\" >> $vardict_script
echo "-b '/mnt/${tumor_bam}' \\" >> $vardict_script
echo "-Q 1 -c 1 -S 2 -E 3 -g 4 /mnt/${input_bed} \\" >> $vardict_script
echo "> /mnt/${outdir}/${timestamp}.var\"" >> $vardict_script
echo "" >> $vardict_script

echo "docker run --rm -v /:/mnt -u $UID --memory ${MEM} lethalfang/vardictjava:1.5.1 \\" >> $vardict_script
echo "bash -c \"cat /mnt/${outdir}/${timestamp}.var | awk 'NR!=1' | /opt/VarDict/teststrandbias.R | /opt/VarDict/var2vcf_valid.pl -N 'TUMOR' -f $VAF \\" >> $vardict_script
echo "> /mnt/${outdir}/${outvcf}\"" >> $vardict_script

echo "" >> $vardict_script
echo 'echo -e "Done at `date +"%Y/%m/%d %H:%M:%S"`" 1>&2' >> $vardict_script

${action} $vardict_script
