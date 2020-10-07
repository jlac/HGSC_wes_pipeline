#! /bin/bash

###################
#
# Launching shell script for NIAID CSI batch processing of WES data
#
###################
module load snakemake/5.8.2-Python-3.6.7

##
## Location of snakemake
##
DIR="$( cd -P "$( dirname "$0" )" >/dev/null 2>&1 && pwd )"
echo "Running script from ${DIR}"

##
## Test commandline arguments
##
if [ $# -ne 2 ]; then
    echo " " 
    echo "Requires a single commandline argument: gris, npr, or process"
    echo " " 
    exit
fi

if [ $2 != "gris" ] && [ $2 != "npr" ] && [ $2 != "process" ] && [ $2 != "himem" ] ; then
    echo " " 
    echo "Invalid commandline option: $2"
    echo "Valid commandline options include: gris, npr, or process"
    echo " " 
    exit
fi

##
## Get batch and batch number
##
batchdir=`pwd`
batch=`echo $batchdir | sed -e 's/^.*\///' `
echo "BATCH: $batch"
batchnumber=`echo $batch | sed -e 's/BATCH//' -e 's/^0//' `
echo "Processing Batch $batchnumber"

##
## Find the raw directory
##
#raw_root="/data/NCBR/rawdata/csi_test_batch"
raw_dir=$1

if ! test -d "rawdata"; then
    if test -d $raw_dir; then
        echo "Linking rawdata subdirectory to $raw_dir"
        ln -s $raw_dir rawdata
    else
        echo "Unable to locate raw data directory $raw_dir"
        echo "Exiting"
        exit
    fi
else
    echo "input directory rawdata already exists"
fi

##
## Make the new output directories
##
for i in BAM VCF QC/TARGET QC/UCSC BATCH_QC HLA inbreeding CNV_100
do
    if ! test -d $i; then
        echo "Creating output directory: $i"
        mkdir -p $i
    else
        echo "output directory $i already exists"
    fi
done
# and be sure this directory and all subdirectories are writable
chmod -fR g+rwx .

SCRIPT=`realpath $0`
SCRIPTPATH=`dirname $SCRIPT`

echo $SCRIPT
echo $SCRIPTPATH

##
## Run csi_to_gris.py
##
if [ "$2" == "gris" ] 
then
    echo "Running csi_to_gris"
    python3 "$SCRIPTPATH/"csi_to_gris_hgsc.py -b $batchnumber -d $raw_dir -s $raw_dir/sample_key.xlsx
    exit
fi

mkdir -p snakejobs
mkdir -p BATCH_QC

##
## Run snakemake
##
echo "Run snakemake"

CLUSTER_OPTS="sbatch --gres {cluster.gres} --cpus-per-task {cluster.threads} -p {cluster.partition} -t {cluster.time} --mem {cluster.mem} --job-name={params.rname} -e snakejobs/slurm-%j_{params.rname}.out -o snakejobs/slurm-%j_{params.rname}.out --chdir=$batchdir"

if [ "$2" == "npr" ]
then
    snakemake -npr --snakefile CSI_wes_pipeline/scripts/hgsc_wgs_batch_processing_hg38.snakemake
fi

if [ "$2" == "process" ]
then
    snakemake --stats snakemake.stats --restart-times 1 --rerun-incomplete -j 150 --cluster "$CLUSTER_OPTS" --cluster-config CSI_wes_pipeline/resources/processing_cluster_locus.json --keep-going --snakefile CSI_wes_pipeline/scripts/hgsc_wgs_batch_processing_hg38.snakemake 2>&1|tee -a csi_batch_processing.log
fi