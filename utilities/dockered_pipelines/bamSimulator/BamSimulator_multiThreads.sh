#!/bin/bash
# Use getopt instead of getopts for long options

set -e

OPTS=`getopt -o o: --long output-dir:,genome-reference:,selector:,tumor-bam-out:,tumor-bam-in:,normal-bam-out:,normal-bam-in:,split-proportion:,down-sample:,num-snvs:,num-indels:,num-svs:,min-vaf:,max-vaf:,left-beta:,right-beta:,min-depth:,max-depth:,min-variant-reads:,out-script:,seed:,action:,threads:,merge-bam,split-bam,clean-bam,indel-realign,keep-intermediates -n 'BamSimulator.sh'  -- "$@"`

if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

echo "$OPTS"
eval set -- "$OPTS"

MYDIR="$( cd "$( dirname "$0" )" && pwd )"

timestamp=$( date +"%Y-%m-%d_%H-%M-%S_%N" )
action=echo
seed=$( date +"%Y" )
min_depth=5
max_depth=5000
min_var_reads=1
num_snvs=500
num_indels=100
num_svs=0
min_vaf=0.05
max_vaf=0.5
min_var_reads=1
down_sample=1
left_beta=2
right_beta=2

threads=12

while true; do
    case "$1" in
        -o | --output-dir )
            case "$2" in
                "") shift 2 ;;
                *)  parent_outdir=$2 ; shift 2 ;;
            esac ;;
            
        --genome-reference )
            case "$2" in
                "") shift 2 ;;
                *)  HUMAN_REFERENCE=$2 ; shift 2 ;;
            esac ;;

        --selector )
            case "$2" in
                "") shift 2 ;;
                *) SELECTOR=$2 ; shift 2 ;;
            esac ;;

        --tumor-bam-out )
            case "$2" in
                "") shift 2 ;;
                *)  out_tumor=$2 ; shift 2 ;;
            esac ;;

        --tumor-bam-in )
            case "$2" in
                "") shift 2 ;;
                *)  in_tumor_whole=$2 ; shift 2 ;;
            esac ;;

        --normal-bam-out )
            case "$2" in
                "") shift 2 ;;
                *)  out_normal=$2 ; shift 2 ;;
            esac ;;

        --normal-bam-in )
            case "$2" in
                "") shift 2 ;;
                *)  in_normal_whole=$2 ; shift 2 ;;
            esac ;;

        --split-proportion )
            case "$2" in
                "") shift 2 ;;
                *)  proportion=$2 ; shift 2 ;;
            esac ;;

        --down-sample )
            case "$2" in
                "") shift 2 ;;
                *)  down_sample=$2 ; shift 2 ;;
            esac ;;

        --num-snvs )
            case "$2" in
                "") shift 2 ;;
                *)  num_snvs=$2 ; shift 2 ;;
            esac ;;

        --num-indels )
            case "$2" in
                "") shift 2 ;;
                *)  num_indels=$2 ; shift 2 ;;
            esac ;;

        --num-svs )
            case "$2" in
                "") shift 2 ;;
                *)  num_svs=$2 ; shift 2 ;;
            esac ;;

        --min-vaf )
            case "$2" in
                "") shift 2 ;;
                *)  min_vaf=$2 ; shift 2 ;;
            esac ;;

        --max-vaf )
            case "$2" in
                "") shift 2 ;;
                *)  max_vaf=$2 ; shift 2 ;;
            esac ;;

        --left-beta )
            case "$2" in
                "") shift 2 ;;
                *)  left_beta=$2 ; shift 2 ;;
            esac ;;

        --right-beta )
            case "$2" in
                "") shift 2 ;;
                *)  right_beta=$2 ; shift 2 ;;
            esac ;;

        --min-depth )
            case "$2" in
                "") shift 2 ;;
                *)  min_depth=$2 ; shift 2 ;;
            esac ;;

        --max-depth )
            case "$2" in
                "") shift 2 ;;
                *)  max_depth=$2 ; shift 2 ;;
            esac ;;

        --min-variant-reads )
            case "$2" in
                "") shift 2 ;;
                *)  min_var_reads=$2 ; shift 2 ;;
            esac ;;

        --out-script )
            case "$2" in
                "") shift 2 ;;
                *)  out_script_name=$2 ; shift 2 ;;
            esac ;;

        --action )
            case "$2" in
                "") shift 2 ;;
                *)  action=$2 ; shift 2 ;;
            esac ;;

        --seed )
            case "$2" in
                "") shift 2 ;;
                *)  seed=$2 ; shift 2 ;;
            esac ;;

        --threads )
            case "$2" in
                "") shift 2 ;;
                *)  threads=$2 ; shift 2 ;;
            esac ;;

        --merge-bam )
            merge_bam=1 ; shift ;;

        --split-bam )
            split_bam=1 ; shift ;;

        --clean-bam )
            clean_bam=1 ; shift ;;

        --indel-realign )
            indel_realign=1 ; shift ;;

        --keep-intermediates )
            keep_intermediates=1 ; shift ;;

        -- ) shift; break ;;
        * ) break ;;
    esac
done

hg_dict=${HUMAN_REFERENCE%\.fa*}.dict

per_thread_snvs=$(( $num_snvs / $threads ))
per_thread_indels=$(( $num_indels / $threads ))
per_thread_svs=$(( $num_svs / $threads ))

VERSION='latest'

timestamp=$( date +"%Y-%m-%d_%H-%M-%S_%N" )
parent_logdir=${parent_outdir}/logs
mkdir -p ${parent_logdir}

if [[ $SELECTOR ]]
then
    cp $SELECTOR ${parent_outdir}/genome.bed
else
    cat ${HUMAN_REFERENCE}.fai | awk -F "\t" '{print $1 "\t0\t" $2}' | awk -F "\t" '$1 ~ /^(chr)?[0-9XY]+$/' > ${parent_outdir}/genome.bed
fi

docker run --rm -v /:/mnt -u $UID -i lethalfang/somaticseq:${VERSION} \
/opt/somaticseq/utilities/split_Bed_into_equal_regions.py \
-infile /mnt/${parent_outdir}/genome.bed -num $threads -outfiles /mnt/${parent_outdir}/bed


ith_thread=1
while [[ $ith_thread -le $threads ]]
do

    outdir="${parent_outdir}/${ith_thread}"
    logdir="${outdir}/logs"

    mkdir -p ${logdir}
    
    mv ${parent_outdir}/${ith_thread}.bed ${outdir}
    
    ith_selector="${outdir}/${ith_thread}.bed"
    
    if [[ ${out_script_name} ]]
    then
        out_script="${logdir}/${out_script_name}"
    else
        out_script="${logdir}/BamSimulator.${timestamp}.cmd"    
    fi
    
    echo "#!/bin/bash" > $out_script
    echo "" >> $out_script
    
    echo "#$ -o ${logdir}" >> $out_script
    echo "#$ -e ${logdir}" >> $out_script
    echo "#$ -S /bin/bash" >> $out_script
    echo '#$ -l h_vmem=14G' >> $out_script
    echo 'set -e' >> $out_script
    echo "" >> $out_script
    
    files_to_delete=''
    
    echo 'echo -e "Start at `date +"%Y/%m/%d %H:%M:%S"`" 1>&2' >> $out_script
    echo "" >> $out_script
    
    
    # Split the BAM files to the ith region:
    $MYDIR/bamSurgeon/split_BAM_by_BED.sh \
    --output-dir ${outdir} \
    --bam-in ${in_tumor_whole} \
    --bam-out ${ith_thread}.tumor.bam \
    --selector ${ith_selector} \
    --out-script $out_script
    
    in_tumor="${outdir}/${ith_thread}.tumor.bam"
    files_to_delete="${outdir}/${ith_thread}.tumor.bam ${outdir}/${ith_thread}.tumor.bam.bai $files_to_delete"
    
    # Split for normal
    if [[ $in_normal_whole ]]
    then
        $MYDIR/bamSurgeon/split_BAM_by_BED.sh \
        --output-dir ${outdir} \
        --bam-in ${in_normal_whole} \
        --bam-out ${ith_thread}.normal.bam \
        --selector ${ith_selector} \
        --out-script $out_script
        
        files_to_delete="${outdir}/${ith_thread}.normal.bam ${outdir}/${ith_thread}.normal.bam.bai $files_to_delete"
    fi
    
    in_normal="${outdir}/${ith_thread}.normal.bam"
    
    # By default, the input tumor gets to be added until instructed otherwise:
    bam_file_to_be_split=${in_tumor}
    bam_file_for_spikein=${in_tumor}

    # If TRUE, two bam files will be merged, sorted by QNAMES. 
    if [[ $merge_bam ]]
    then
        $MYDIR/bamSurgeon/MergeTN.sh \
        --tumor-bam  ${in_tumor} \
        --normal-bam ${in_normal} \
        --output-dir ${outdir} \
        --bam-out    TNMerged.bam \
        --out-script $out_script
        
        bam_file_to_be_split="${outdir}/TNMerged.bam"
        files_to_delete="${outdir}/TNMerged.bam $files_to_delete"
    fi
    
    
    # If TRUE, the QNAME-sorted BAM file will be split, then the two BAM files will be properly sorted and indexed. So that the designated tumor can be used for spike in. 
    if [[ $split_bam ]]
    then
            
        if [[ $clean_bam ]]
        then

            $MYDIR/bamSurgeon/SortByReadName.sh \
            --output-dir ${outdir} \
            --bam-in ${outdir}/TNMerged.bam \
            --bam-out qnameSorted.bam \
            --out-script $out_script
            
            $MYDIR/bamSurgeon/cleanBam.sh \
            --output-dir ${outdir} \
            --bam-in ${outdir}/qnameSorted.bam \
            --bam-out Cleaned.bam \
            --out-script $out_script
            
            $MYDIR/bamSurgeon/SortByCoordinate.sh \
            --output-dir ${outdir} \
            --genome-reference ${HUMAN_REFERENCE} \            
            --bam-in ${outdir}/Cleaned.bam \
            --bam-out Sorted.bam \
            --out-script $out_script
            
            bam_file_to_be_split="${outdir}/Sorted.bam"
            files_to_delete="${outdir}/qnameSorted.bam ${outdir}/Cleaned.bam ${outdir}/Sorted.bam ${outdir}/Sorted.bam.bai $files_to_delete"

        fi
        
        $MYDIR/bamSurgeon/bamsurgeon_split_BAM.sh \
        --genome-reference ${HUMAN_REFERENCE} \
        --output-dir ${outdir} \
        --bam-in ${bam_file_to_be_split} \
        --bam-out1 ${out_normal} \
        --bam-out2 Designated.Tumor.bam \
        --split-proportion ${proportion} \
        --down-sample ${down_sample} \
        --seed $seed \
        --out-script $out_script
    
        bam_file_for_spikein="${outdir}/Designated.Tumor.bam"
        files_to_delete="${outdir}/Designated.Tumor.bam ${outdir}/Designated.Tumor.bam.bai $files_to_delete"
    
    # If DO NOT SPLIT, then need to use the original "in_tumor" for spikein. Without splitting, the original normal is the output normal
    else
    
        # Unless it needs to be cleaned:
        if [[ $clean_bam ]]
        then
            $MYDIR/bamSurgeon/SortByReadName.sh \
            --output-dir ${outdir} \
            --bam-in ${in_tumor} \
            --bam-out qnameSorted.bam \
            --out-script $out_script
            
            $MYDIR/bamSurgeon/cleanBam.sh \
            --output-dir ${outdir} \
            --bam-in ${outdir}/qnameSorted.bam \
            --bam-out Cleaned.bam \
            --out-script $out_script
            
            $MYDIR/bamSurgeon/SortByCoordinate.sh \
            --output-dir ${outdir} \
            --bam-in ${outdir}/Cleaned.bam \
            --bam-out Sorted.bam \
            --out-script $out_script
            
            bam_file_to_be_split="${outdir}/Sorted.bam"
            files_to_delete="${outdir}/qnameSorted.bam ${outdir}/Cleaned.bam ${outdir}/Sorted.bam ${outdir}/Sorted.bam.bai $files_to_delete"
        fi
        
        bam_file_for_spikein="${in_tumor}"
        ln -s /mnt/${in_normal}     ${outdir}/${out_normal}
        ln -s /mnt/${in_normal}.bai ${outdir}/${out_normal}.bai
    fi


    $MYDIR/bamSurgeon/bamsurgeon_random_sites.sh \
    --output-dir ${outdir} \
    --genome-reference ${HUMAN_REFERENCE} \
    --selector ${ith_selector} \
    --num-snvs ${per_thread_snvs} --num-indels ${per_thread_indels} --num-svs ${per_thread_svs} \
    --min-vaf ${min_vaf} --max-vaf ${max_vaf} \
    --left-beta ${left_beta} --right-beta ${right_beta} \
    --seed $seed \
    --out-script $out_script
    
    
    $MYDIR/bamSurgeon/bamsurgeon_addsnvs.sh \
    --output-dir ${outdir} \
    --genome-reference ${HUMAN_REFERENCE} \
    --bam-in ${bam_file_for_spikein} \
    --bam-out snvs.added.bam \
    --snvs ${outdir}/random_sSNV.bed \
    --cnv-file ${outdir}/sorted.cnvfile.bed.gz \
    --min-vaf ${min_vaf} --max-vaf ${max_vaf} \
    --min-depth ${min_depth} --max-depth ${max_depth} --min-variant-reads ${min_var_reads} \
    --seed $seed \
    --out-script $out_script
    
    
    $MYDIR/bamSurgeon/bamsurgeon_addindels.sh \
    --output-dir ${outdir} \
    --genome-reference ${HUMAN_REFERENCE} \
    --bam-in ${outdir}/snvs.added.bam  \
    --bam-out snvs.indels.added.bam \
    --indels ${outdir}/random_sINDEL.bed \
    --cnv-file ${outdir}/sorted.cnvfile.bed.gz \
    --min-vaf ${min_vaf} --max-vaf ${max_vaf} \
    --min-depth ${min_depth} --max-depth ${max_depth} --min-variant-reads ${min_var_reads} \
    --seed $seed \
    --out-script $out_script
    
    files_to_delete="$files_to_delete ${outdir}/snvs.added.bam ${outdir}/snvs.added.bam.bai"
    final_tumor_bam=${outdir}/snvs.indels.added.bam
    
    
    if [[ $num_svs -gt 0 ]]
    then
        $MYDIR/bamSurgeon/bamsurgeon_addsvs.sh \
        --output-dir ${outdir} \
        --genome-reference ${HUMAN_REFERENCE} \
        --bam-in ${outdir}/snvs.indels.added.bam \
        --bam-out snvs.indels.svs.added.bam \
        --cnv-file ${outdir}/sorted.cnvfile.bed.gz \
        --svs ${outdir}/random_sSV.bed \
        --seed $seed \
        --out-script $out_script
            
        final_tumor_bam=${outdir}/snvs.indels.svs.added.bam
        files_to_delete="$files_to_delete ${outdir}/snvs.indels.added.bam ${outdir}/snvs.indels.added.bam.bai"
    fi
    
    
    echo "" >> $out_script
    echo "mv ${final_tumor_bam} ${outdir}/${out_tumor}" >> $out_script
    echo "mv ${final_tumor_bam}.bai ${outdir}/${out_tumor}.bai" >> $out_script
    echo "" >> $out_script
    
    if [[ $indel_realign ]]
    then
        $MYDIR/bamSurgeon/IndelRealign.sh \
        --tumor-bam ${outdir}/${out_tumor} \
        --normal-bam ${outdir}/${out_normal} \
        --genome-reference ${HUMAN_REFERENCE} \
        --output-dir ${outdir} \
        --selector ${ith_selector} \
        --out-script $out_script
    fi
    
    
    echo "" >> $out_script
    
    if [[ ! $keep_intermediates ]]
    then
        echo "for file in $files_to_delete" >> $out_script
        echo "do" >> $out_script
        echo "    rm \$file" >> $out_script
        echo "done" >> $out_script
    fi
    
    echo 'echo -e "Done at `date +"%Y/%m/%d %H:%M:%S"`" 1>&2' >> $out_script

    ${action} $out_script

    ith_thread=$(( $ith_thread + 1))

done
