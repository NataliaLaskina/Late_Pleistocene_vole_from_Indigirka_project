### Ancient mitogenome assembly script: `scripts/04_ancient_mitogenome_assembly.sh`
#!/bin/bash
#===============================================================================
# Pipeline: Assembly of ancient Microtus miurus mitogenome
# Method: Mapping to reference genome (M. miurus)
# Dependencies: bwa v0.7.17, samtools v1.10, bcftools v1.10+, bedtools v2.31+
#===============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

#===============================================================================
# CONFIGURATION
#===============================================================================

# Download from NCBI GenBank
# Search: Microtus miurus mitogenome (GenBank: MT381943)
# Save as: PROJECT_DIR/references/mitogenomes/M_miurus_mito.fasta

# Paths (relative to project root)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REF_GENOME="$PROJECT_DIR/references/mitogenomes/M_miurus_mito.fasta"
READS="$PROJECT_DIR/results/preprocessing/adapterremoval/miurus.collapsed.fastq.gz"
OUTDIR="$PROJECT_DIR/results/mito_mapping"

# Create output directories
mkdir -p "$OUTDIR"/{01_reference,02_mapping,03_consensus,04_qc}

# Parameters for ancient DNA
BWA_THREADS=8
BWA_MISMATCH_RATE=0.04     # Allow up to 4% mismatches (aDNA damage + cross-species)
BWA_SEED_LEN=1024          # Disable seeding (important for short aDNA reads)
SAMTOOLS_MIN_MAPQ=20       # Minimum mapping quality (error probability ≤1%)
BCFTOOLS_MIN_DP=3          # Minimum depth for variant calling
BCFTOOLS_MIN_QUAL=20       # Minimum quality score

echo "=========================================="
echo "Ancient Mitogenome Assembly Pipeline"
echo "=========================================="
echo "Reference: $REF_GENOME"
echo "Reads: $READS"
echo "Output: $OUTDIR"
echo ""

#===============================================================================
# STEP 1: Prepare reference genome
#===============================================================================

echo "[1/5] Preparing reference genome..."

# Download M. abbreviatus mitogenome (if not exists)
if [[ ! -f "$REF_GENOME" ]]; then
    echo "Downloading reference mitogenome (MT381943)..."
    mkdir -p "$(dirname "$REF_GENOME")"
    efetch -db nucleotide -id MT381943 -format fasta > "$REF_GENOME"
fi

# Index reference for BWA and SAMtools
bwa index "$REF_GENOME"
samtools faidx "$REF_GENOME"

# Copy to mapping directory
cp "$REF_GENOME"* "$OUTDIR/01_reference/"

echo "✓ Reference prepared: $(grep -c '^>' "$REF_GENOME") sequence(s)"
echo ""

#===============================================================================
# STEP 2: Map reads to mitogenome
#===============================================================================

echo "[2/5] Mapping reads to reference..."

BAM_FILE="$OUTDIR/02_mapping/miurus_mito.bam"

# BWA aln (optimized for ancient DNA)
# -n: mismatch rate (higher for aDNA due to damage)
# -l: seed length (disabled for short reads)
bwa aln -n "$BWA_MISMATCH_RATE" -l "$BWA_SEED_LEN" -t "$BWA_THREADS" \
    "$REF_GENOME" "$READS" > "$OUTDIR/02_mapping/miurus.sai"

# Convert to BAM, filter, and sort
bwa samse "$REF_GENOME" "$OUTDIR/02_mapping/miurus.sai" "$READS" | \
    samtools view -@ "$BWA_THREADS" -bS \
        -q "$SAMTOOLS_MIN_MAPQ" \
        -F 2308 | \  # Remove unmapped (4), secondary (256), supplementary (2048)
    samtools sort -@ "$BWA_THREADS" -o "$BAM_FILE"

# Index BAM file
samtools index "$BAM_FILE"

# Cleanup intermediate files
rm -f "$OUTDIR/02_mapping/miurus.sai"

echo "✓ Mapping complete: $(samtools view -c "$BAM_FILE") reads mapped"
echo ""

#===============================================================================
# STEP 3: Quality control
#===============================================================================

echo "[3/5] Running quality control..."

# Mapping statistics
samtools flagstat "$BAM_FILE" > "$OUTDIR/04_qc/mito_flagstat.txt"

# Coverage analysis
bedtools genomecov -ibam "$BAM_FILE" -bga > "$OUTDIR/04_qc/mito_coverage.bedgraph"

# Calculate coverage statistics
MEAN_COVERAGE=$(awk '
    $4<=1000 && $4>0 {sum+=$4; count++}
    END {if(count>0) printf "%.1f", sum/count; else print "0"}
' \
    "$OUTDIR/04_qc/mito_coverage.bedgraph")

COVERED_BASES=$(awk '$4>=1 {covered+=$3-$2} END {print covered}' \
    "$OUTDIR/04_qc/mito_coverage.bedgraph")

MITO_LENGTH=$(samtools faidx "$REF_GENOME" | awk 'NR==2 {print length($0)}')

echo "  Mean coverage: ${MEAN_COVERAGE}x"
echo "  Covered bases: $COVERED_BASES / $MITO_LENGTH bp"
echo "  Coverage: $(awk "BEGIN {printf \"%.1f\", ($COVERED_BASES/$MITO_LENGTH)*100}")%"
echo ""

#===============================================================================
# STEP 4: Call variants and generate consensus
#===============================================================================

echo "[4/5] Calling variants and generating consensus..."

VCF_FILE="$OUTDIR/03_consensus/miurus_mito.filtered.vcf.gz"
CONSENSUS_FILE="$OUTDIR/03_consensus/miurus_ancient_mitogenome.fasta"

# Call variants (bcftools mpileup + call)
bcftools mpileup -f "$REF_GENOME" -Q 20 -C 50 "$BAM_FILE" | \
    bcftools call -c -Oz -o "$OUTDIR/03_consensus/miurus_mito.vcf.gz"

# Filter variants
bcftools filter -i "DP>=$BCFTOOLS_MIN_DP && QUAL>=$BCFTOOLS_MIN_QUAL" \
    "$OUTDIR/03_consensus/miurus_mito.vcf.gz" -Oz -o "$VCF_FILE"

# Index VCF
bcftools index "$VCF_FILE"

# Generate consensus sequence (fill uncovered positions with 'N')
bcftools consensus -f "$REF_GENOME" -a N "$VCF_FILE" > "$CONSENSUS_FILE"

# Rename sequence
sed -i '1s/>.*/>Miurus_Indigirka_Egorovi/' "$CONSENSUS_FILE"

echo "✓ Consensus generated: $(grep -v '^>' "$CONSENSUS_FILE" | tr -d '\n' | wc -c) bp"
echo ""

#===============================================================================
# STEP 5: Final statistics
#===============================================================================

echo "[5/5] Final statistics..."

TOTAL_LENGTH=$(grep -v '^>' "$CONSENSUS_FILE" | tr -d '\n' | wc -c)
N_COUNT=$(grep -v '^>' "$CONSENSUS_FILE" | tr -d '\n' | grep -o 'N' | wc -l)
N_PERCENT=$(awk "BEGIN {printf \"%.2f\", ($N_COUNT/$TOTAL_LENGTH)*100}")
CONFIDENT_BASES=$((TOTAL_LENGTH - N_COUNT))

echo "=========================================="
echo "ASSEMBLY SUMMARY"
echo "=========================================="
echo "Total length:        $TOTAL_LENGTH bp"
echo "Confident bases:     $CONFIDENT_BASES bp ($(awk "BEGIN {printf \"%.1f\", (100-$N_PERCENT)}")%)"
echo "Uncertain bases (N): $N_COUNT bp ($N_PERCENT%)"
echo "Mean coverage:       ${MEAN_COVERAGE}x"
echo "Mapped reads:        $(samtools view -c "$BAM_FILE")"
echo "=========================================="
echo ""
echo "Output files:"
echo "  - Consensus: $CONSENSUS_FILE"
echo "  - BAM: $BAM_FILE"
echo "  - VCF: $VCF_FILE"
echo "  - QC stats: $OUTDIR/04_qc/"
echo ""
echo "Pipeline completed successfully! ✓"