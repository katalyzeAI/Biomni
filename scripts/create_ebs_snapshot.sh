#!/usr/bin/env bash
# Create an EBS snapshot pre-populated with the Biomni data lake.
#
# This script:
#   1. Launches a temporary EC2 instance
#   2. Creates and attaches a 15 GiB gp3 EBS volume
#   3. Downloads the data lake (78 files) and benchmark dataset from S3
#   4. Creates a snapshot tagged "biomni-data-lake-v1"
#   5. Cleans up (terminates instance, deletes volume)
#
# Usage:
#   bash scripts/create_ebs_snapshot.sh
#
# Prerequisites:
#   - AWS CLI configured with appropriate permissions
#   - jq installed
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
AZ="${REGION}a"
VOLUME_SIZE=15
INSTANCE_TYPE="t3.medium"
SNAPSHOT_TAG="biomni-data-lake-v1"

# Latest Amazon Linux 2023 AMI
AMI_ID=$(aws ec2 describe-images \
    --region "$REGION" \
    --owners amazon \
    --filters "Name=name,Values=al2023-ami-2023*-x86_64" \
              "Name=state,Values=available" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text)

echo "==> Using AMI: $AMI_ID"

# Data lake files (from biomni/env_desc.py)
DATA_LAKE_FILES=(
    "affinity_capture-ms.parquet"
    "affinity_capture-rna.parquet"
    "BindingDB_All_202409.tsv"
    "broad_repurposing_hub_molecule_with_smiles.parquet"
    "broad_repurposing_hub_phase_moa_target_info.parquet"
    "co-fractionation.parquet"
    "czi_census_datasets_v4.parquet"
    "DepMap_CRISPRGeneDependency.csv"
    "DepMap_CRISPRGeneEffect.csv"
    "DepMap_Model.csv"
    "DepMap_OmicsExpressionProteinCodingGenesTPMLogp1.csv"
    "ddinter_alimentary_tract_metabolism.csv"
    "ddinter_antineoplastic.csv"
    "ddinter_antiparasitic.csv"
    "ddinter_blood_organs.csv"
    "ddinter_dermatological.csv"
    "ddinter_hormonal.csv"
    "ddinter_respiratory.csv"
    "ddinter_various.csv"
    "DisGeNET.parquet"
    "dosage_growth_defect.parquet"
    "enamine_cloud_library_smiles.pkl"
    "evebio_assay_table.csv"
    "evebio_bundle_table.csv"
    "evebio_compound_table.csv"
    "evebio_control_table.csv"
    "evebio_detailed_result_table.csv"
    "evebio_observed_points_table.csv"
    "evebio_summary_result_table.csv"
    "evebio_target_table.csv"
    "genebass_missense_LC_filtered.pkl"
    "genebass_pLoF_filtered.pkl"
    "genebass_synonymous_filtered.pkl"
    "gene_info.parquet"
    "genetic_interaction.parquet"
    "go-plus.json"
    "gtex_tissue_gene_tpm.parquet"
    "gwas_catalog.pkl"
    "hp.obo"
    "kg.csv"
    "marker_celltype.parquet"
    "McPAS-TCR.parquet"
    "miRDB_v6.0_results.parquet"
    "miRTarBase_microRNA_target_interaction.parquet"
    "miRTarBase_microRNA_target_interaction_pubmed_abtract.txt"
    "miRTarBase_MicroRNA_Target_Sites.parquet"
    "mousemine_m1_positional_geneset.parquet"
    "mousemine_m2_curated_geneset.parquet"
    "mousemine_m3_regulatory_target_geneset.parquet"
    "mousemine_m5_ontology_geneset.parquet"
    "mousemine_m8_celltype_signature_geneset.parquet"
    "mousemine_mh_hallmark_geneset.parquet"
    "msigdb_human_c1_positional_geneset.parquet"
    "msigdb_human_c2_curated_geneset.parquet"
    "msigdb_human_c3_regulatory_target_geneset.parquet"
    "msigdb_human_c3_subset_transcription_factor_targets_from_GTRD.parquet"
    "msigdb_human_c4_computational_geneset.parquet"
    "msigdb_human_c5_ontology_geneset.parquet"
    "msigdb_human_c6_oncogenic_signature_geneset.parquet"
    "msigdb_human_c7_immunologic_signature_geneset.parquet"
    "msigdb_human_c8_celltype_signature_geneset.parquet"
    "msigdb_human_h_hallmark_geneset.parquet"
    "omim.parquet"
    "proteinatlas.tsv"
    "proximity_label-ms.parquet"
    "reconstituted_complex.parquet"
    "sgRNA_KO_SP_mouse.txt"
    "sgRNA_KO_SP_human.txt"
    "synthetic_growth_defect.parquet"
    "synthetic_lethality.parquet"
    "synthetic_rescue.parquet"
    "two-hybrid.parquet"
    "variant_table.parquet"
    "Virus-Host_PPI_P-HIPSTER_2020.parquet"
    "txgnn_name_mapping.pkl"
    "txgnn_prediction.pkl"
)

S3_BASE="https://biomni-release.s3.amazonaws.com"

# ─── Create a user-data script for the instance ─────────────
USERDATA=$(cat <<'SCRIPT'
#!/bin/bash
set -euo pipefail

# Wait for the EBS volume to appear
while [ ! -b /dev/xvdf ]; do sleep 1; done

mkfs.ext4 /dev/xvdf
mkdir -p /mnt/data_lake
mount /dev/xvdf /mnt/data_lake

mkdir -p /mnt/data_lake/biomni_data/data_lake
mkdir -p /mnt/data_lake/biomni_data/benchmark

# Signal that setup is done
touch /tmp/volume_ready
SCRIPT
)

echo "==> Launching temporary EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --region "$REGION" \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --placement "AvailabilityZone=$AZ" \
    --user-data "$USERDATA" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=biomni-snapshot-builder}]" \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "    Instance: $INSTANCE_ID"
echo "==> Waiting for instance to run..."
aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_ID"

echo "==> Creating 15 GiB gp3 volume..."
VOLUME_ID=$(aws ec2 create-volume \
    --region "$REGION" \
    --availability-zone "$AZ" \
    --volume-type gp3 \
    --size "$VOLUME_SIZE" \
    --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=biomni-data-lake-build}]" \
    --query 'VolumeId' \
    --output text)

echo "    Volume: $VOLUME_ID"
aws ec2 wait volume-available --region "$REGION" --volume-ids "$VOLUME_ID"

echo "==> Attaching volume to instance..."
aws ec2 attach-volume \
    --region "$REGION" \
    --volume-id "$VOLUME_ID" \
    --instance-id "$INSTANCE_ID" \
    --device /dev/xvdf

echo "==> Waiting for volume to attach..."
aws ec2 wait volume-in-use --region "$REGION" --volume-ids "$VOLUME_ID"

# Wait for user-data to finish formatting/mounting
echo "==> Waiting for instance setup (user-data)..."
sleep 30

# Use SSM to download files (requires SSM agent — installed by default on AL2023)
echo "==> Downloading data lake files (${#DATA_LAKE_FILES[@]} files)..."
DOWNLOAD_CMD="cd /mnt/data_lake/biomni_data/data_lake"
for f in "${DATA_LAKE_FILES[@]}"; do
    DOWNLOAD_CMD="$DOWNLOAD_CMD && curl -sSfL -o '$f' '${S3_BASE}/data_lake/$f'"
done

aws ssm send-command \
    --region "$REGION" \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"$DOWNLOAD_CMD\"]" \
    --timeout-seconds 3600 \
    --output text > /dev/null

echo "==> Downloading benchmark dataset..."
aws ssm send-command \
    --region "$REGION" \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"cd /mnt/data_lake/biomni_data && curl -sSfL -o benchmark.zip '${S3_BASE}/benchmark.zip' && unzip -o benchmark.zip -d benchmark/ && rm benchmark.zip\"]" \
    --timeout-seconds 1800 \
    --output text > /dev/null

echo "==> Waiting for downloads to complete (this may take 20-40 minutes)..."
echo "    Monitor progress in the SSM console or with:"
echo "    aws ssm list-command-invocations --region $REGION --instance-id $INSTANCE_ID"
echo ""
echo "    Press Ctrl+C to detach (instance will keep downloading)."
echo "    Re-run this section manually when done, or wait..."
sleep 600  # Wait 10 minutes as a rough estimate

echo "==> Unmounting volume..."
aws ssm send-command \
    --region "$REGION" \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"sync && umount /mnt/data_lake\"]" \
    --timeout-seconds 60 \
    --output text > /dev/null
sleep 10

echo "==> Detaching volume..."
aws ec2 detach-volume --region "$REGION" --volume-id "$VOLUME_ID"
aws ec2 wait volume-available --region "$REGION" --volume-ids "$VOLUME_ID"

echo "==> Creating snapshot..."
SNAPSHOT_ID=$(aws ec2 create-snapshot \
    --region "$REGION" \
    --volume-id "$VOLUME_ID" \
    --description "Biomni data lake — 78 files + benchmark" \
    --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=$SNAPSHOT_TAG}]" \
    --query 'SnapshotId' \
    --output text)

echo "    Snapshot: $SNAPSHOT_ID"
echo "==> Waiting for snapshot to complete (may take several minutes)..."
aws ec2 wait snapshot-completed --region "$REGION" --snapshot-ids "$SNAPSHOT_ID"

echo "==> Cleaning up: terminating instance and deleting volume..."
aws ec2 terminate-instances --region "$REGION" --instance-ids "$INSTANCE_ID" > /dev/null
aws ec2 delete-volume --region "$REGION" --volume-id "$VOLUME_ID" 2>/dev/null || true

echo ""
echo "════════════════════════════════════════════════════"
echo "  SNAPSHOT CREATED: $SNAPSHOT_ID"
echo ""
echo "  Add to terraform.tfvars:"
echo "    data_lake_snapshot_id = \"$SNAPSHOT_ID\""
echo "════════════════════════════════════════════════════"
