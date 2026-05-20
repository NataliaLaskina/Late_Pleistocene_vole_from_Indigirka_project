### Mapping script: `scripts/03_map_and_damage.sh`
#!/bin/bash
#===============================================================================
# Pipeline: Mapping and Ancient DNA Damage Assessment
# Tools: BWA aln + SAMtools + Picard + mapDamage
#===============================================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAPPING_DIR="$PROJECT_DIR/results/mapping"
DAMAGE_DIR="$PROJECT_DIR/results/damage"
REF="$PROJECT_DIR/references/Microtus/M_ochrogaster_ref.fna"
COLLAPSED="$PROJECT_DIR/results/preprocessing/02_adapterremoval/02_miurus.collapsed.fastq.gz"

mkdir -p "$MAPPING_DIR"/{tmp,sep_bams,logs} "$DAMAGE_DIR"

echo "=========================================="
echo "Mapping & Damage Analysis Pipeline"
echo "=========================================="
echo ""

#===============================================================================
# STEP 1: BWA aln - Map merged reads
#===============================================================================

echo "[1/3] Mapping collapsed reads with BWA aln..."

cd "$MAPPING_DIR/tmp"

# BWA aln with aDNA-optimized parameters
bwa aln -n 0.04 -l 1024 -t 8 "$REF" "$COLLAPSED" > miurus.sai

# Convert to BAM and filter
bwa samse "$REF" miurus.sai "$COLLAPSED" | \
  samtools view -@ 8 -bS -q 20 -F 2308 | \
  samtools sort -@ 8 -o miurus_merged_sorted.bam

# Index
samtools index miurus_merged_sorted.bam

# Cleanup
rm -f miurus.sai

echo "✓ Mapping complete: $(samtools view -c miurus_merged_sorted.bam) reads"
echo ""

#===============================================================================
# STEP 2: Picard MarkDuplicates
#===============================================================================

echo "[2/3] Marking PCR duplicates with Picard..."

java -Xmx16G -jar ~/apps/picard.jar MarkDuplicates \
  I=miurus_merged_sorted.bam \
  O=../sep_bams/miurus_merged.bam \
  M=../logs/miurus_merged_dup_metrics.txt \
  REMOVE_DUPLICATES=false \
  ASSUME_SORTED=true \
  VALIDATION_STRINGENCY=LENIENT

# Index final BAM
samtools index ../sep_bams/miurus_merged.bam

echo "✓ MarkDuplicates complete"
echo ""

#===============================================================================
# STEP 3: mapDamage analysis
#===============================================================================

echo "[3/3] Running mapDamage analysis..."

cd "$PROJECT_DIR"

mapDamage -i "$MAPPING_DIR/sep_bams/miurus_merged.bam" \
  -r "$REF" \
  -d "$DAMAGE_DIR/mapdamage_results" \
  -l 100

echo "✓ mapDamage complete"
echo ""

echo "=========================================="
echo "PIPELINE COMPLETE"
echo "=========================================="
echo "Output files:"
echo "  - BAM: $MAPPING_DIR/sep_bams/miurus_merged.bam"
echo "  - Damage plots: $DAMAGE_DIR/mapdamage_results/"
echo ""
echo "Check for characteristic aDNA damage patterns (C→T at 5' ends)"