**Requirement**
* Have internet connection, and able to pull and run docker images from Docker Hub, as we have dockerized the entire BAMSurgeon workflow. 
* **Recommended**: Have cluster management system with valid "qsub" command, such as Sun Grid Engine (SGE).

**Example Command for single-thread jobs**
```
$PATH/TO/somaticseq/utilities/dockered_pipelines/bamSimulator/BamSimulator_singleThread.sh \
--genome-reference  /ABSOLUTE/PATH/TO/GRCh38.fa \
--selector          /ABSOLUTE/PATH/TO/Exome_Capture.GRCh38.bed \
--tumor-bam-in      /ABSOLUTE/PATH/TO/Tumor_Sample.bam \
--normal-bam-in     /ABSOLUTE/PATH/TO/Normal_Sample.bam \
--tumor-bam-out     syntheticTumor.bam \
--normal-bam-out    syntheticNormal.bam \
--split-proportion  0.5 \
--num-snvs          300 \
--num-indels        100 \
--num-svs           50 \
--min-vaf           0.05 \
--max-vaf           0.5 \
--min-variant-reads 2 \
--output-dir        /ABSOLUTE/PATH/TO/trainingSet \
--action            qsub
--merge-bam --split-bam --indel-realign
```

**Example Command for multi-thread jobs**
```
$PATH/TO/somaticseq/utilities/dockered_pipelines/bamSimulator/BamSimulator_multiThreads.sh \
--genome-reference  /ABSOLUTE/PATH/TO/GRCh38.fa \
--selector          /ABSOLUTE/PATH/TO/Exome_Capture.GRCh38.bed \
--tumor-bam-in      /ABSOLUTE/PATH/TO/Tumor_Sample.bam \
--normal-bam-in     /ABSOLUTE/PATH/TO/Normal_Sample.bam \
--tumor-bam-out     syntheticTumor.bam \
--normal-bam-out    syntheticNormal.bam \
--split-proportion  0.5 \
--num-snvs          300 \
--num-indels        100 \
--num-svs           50 \
--min-vaf           0.05 \
--max-vaf           0.5 \
--min-variant-reads 2 \
--output-dir        /ABSOLUTE/PATH/TO/trainingSet \
--threads           12 \
--action            qsub
--merge-bam --split-bam --indel-realign
```

**BamSimulator_.sh** creates two semi-simulated tumor-normal pairs out of your input tumor-normal pairs. The "ground truth" of the somatic mutations will be **synthetic_snvs.vcf**, **synthetic_indels.vcf**, and **synthetic_svs.vcf**.

The following options:
* --genome-reference /ABSOLUTE/PATH/TO/human_reference.fa (Required)
* --selector /ABSOLUTE/PATH/TO/capture_region.bed (Required)
* --tumor-bam-in Input BAM file (Required)
* --normal-bam-in Input BAM file (Optional, but required if you want to merge it with the tumor input)
* --tumor-bam-out Output BAM file for the designated tumor after BAMSurgeon mutation spike in
* --normal-bam-out Output BAM file for the designated normal if --split-bam is chosen
* --split-proportion The faction of total reads desginated to the normal. (Defaut = 0.5)
* --num-snvs Number of SNVs to spike into the designated tumor
* --num-indels Number of INDELs to spike into the designated tumor
* --num-svs Number of SVs to spike into the designated tumor (Default = 0)
* --min-depth Minimum depth where spike in can take place
* --max-depth Maximum depth where spike in can take place
* --min-vaf Minimum VAF to simulate
* --max-vaf Maximum VAF to simulate
* --min-variant-reads Minimum number of variant-supporting reads for a successful spike in
* --output-dir Output directory
* --merge-bam Flag to merge the tumor and normal bam file input
* --split-bam Flag to split BAM file for tumor and normal
* --clean-bam Flag to go through the BAM file and remove reads where more than 2 identical read names are present. This was necessary for some BAM files downloaded from TCGA. However, a proper pair-end BAM file should not have the same read name appearing more than twice. Use this only when necessary. 
* --indel-realign Conduct GATK Joint Indel Realignment on the two output BAM files. Instead of syntheticNormal.bam and syntheticTumor.bam, the final BAM files will be **syntheticNormal.JointRealigned.bam** and **syntheticTumor.JointRealigned.bam**.
* --seed Random seed. Pick any integer for reproducibility purposes.
* --threads Split the BAM files evenly in N regions, then process each (pair) of sub-BAM files in parallel. 
* --action The command preceding the run script created into /ABSOLUTE/PATH/TO/BamSurgeoned_SAMPLES/logs. "qsub" is to submit the script in SGE system. Default = echo

**What does that command do**

This is a workflow created using [BAMSurgeon](https://github.com/adamewing/bamsurgeon). 
The command demonstrated above will merge the normal and tumor BAM files into a single BAM file, and then randomly split the merged BAM file into two BAM files. 
One of which is designated normal, and one of which is designated tumor. 
Real somatic mutations in the original tumor will be randomly split into both files, and can be considered germline variants or tummor-normal contamiation. 
Synthetic mutations will then be spiked into the designated tumor to create "real" mutations.
This is the approach described in our [2017 AACR Abstract](http://dx.doi.org/10.1158/1538-7445.AM2017-386). 

<b>A schematic of the simulation procedure</b>
  ![Onkoinsight Simulation](onkoinsight_sim.png)
