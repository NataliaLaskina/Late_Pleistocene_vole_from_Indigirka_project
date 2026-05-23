#!/bin/bash

set -e

echo "========================================="
echo "COMPLETE ASSEMBLY PIPELINE SETUP"
echo "========================================="
echo "Start time: $(date)"
echo ""

# ============================================================================
#1. CHECKING OF THE ENVIRONMENT
# ============================================================================


# Verify installations
echo ""
echo "=== Verifying installed packages ==="
echo -n "  lighter: "
lighter --version 2>&1 | head -1 || echo "✓ installed"
echo -n "  megahit: "
megahit --version 2>&1 | head -1 || echo "✓ installed"
echo -n "  busco: "
busco --version 2>&1 | head -1 || echo "✓ installed"
echo -n "  redundans: "
redundans.py --version 2>&1 | head -1 || echo "✓ installed"


# ============================================================================
# 2. PARAMETERS AND INPUT FILES
# ============================================================================

# Thread allocation for each tool
THREADS=40
MEGAHIT_THREADS=12
REDUNDANS_THREADS=40
BUSCO_THREADS=40


# Input files 
R1="SRR26061978_1.fastq"
R2="SRR26061978_2.fastq"

# Base names for corrected files
R1_BASE="${R1%.fastq}"
R2_BASE="${R2%.fastq}"
R1_BASE="${R1_BASE%.fq}"  # In case file is .fq
R2_BASE="${R2_BASE%.fq}"
CORR_R1="${R1_BASE}.cor.fq"
CORR_R2="${R2_BASE}.cor.fq"


# Check input files
if [ ! -f "$R1" ] || [ ! -f "$R2" ]; then
    echo "ERROR: Input files not found!"
    echo "Expected: $R1 and $R2 in current directory"
    echo "Current directory: $(pwd)"
    echo "Files present:"
    ls -la *.fastq *.fq 2>/dev/null || echo "  No FASTQ files found"
    exit 1
fi

# Create output directories
mkdir -p logs

# ============================================================================
# 3. LOGGING SETUP
# ============================================================================

# Save all output to log file
exec > >(tee -a "logs/assembly_pipeline_$(date +%Y%m%d_%H%M%S).log") 2>&1

echo "========================================="
echo "RUNNING ASSEMBLY PIPELINE"
echo "========================================="
echo "Input files: $R1, $R2"
echo "Threads: $THREADS (total), MEGAHIT: $MEGAHIT_THREADS, Redundans: $REDUNDANS_THREADS"
echo "BUSCO: Using mammalia_odb10 lineage"
echo ""


# ============================================================================
# 4. STEP 1: LIGHTER - ERROR CORRECTION
# ============================================================================

echo ""
echo "=== STEP 1: Lighter Error Correction ==="
echo "Correcting: $R1 and $R2"
echo "Output: $CORR_R1 and $CORR_R2"

# Remove old corrected files if they exist
rm -f "$CORR_R1" "$CORR_R2"

# Run Lighter
lighter -r "$R1" -r "$R2" \
    -K 27 3000000000 \
    -t $THREADS \
    -maxcor 2 \
    -trim \
    -noQual

# Verify files were created
if [ ! -f "$CORR_R1" ] || [ ! -f "$CORR_R2" ]; then
    echo "ERROR: Lighter failed to generate corrected files"
    echo "Expected: $CORR_R1 and $CORR_R2"
    ls -la *.cor.fq 2>/dev/null || echo "No .cor.fq files found"
    exit 1
fi

echo "✓ Error correction complete"
echo "  Corrected R1 size: $(du -h "$CORR_R1" | cut -f1)"
echo "  Corrected R2 size: $(du -h "$CORR_R2" | cut -f1)"

# ============================================================================
# 5. STEP 2: MEGAHIT - GENOME ASSEMBLY
# ============================================================================

echo ""
echo "=== STEP 2: MEGAHIT Assembly ==="
echo "Input: $CORR_R1, $CORR_R2"
echo "Output directory: megahit_optimized"

# Run MEGAHIT (for regular genome, not metagenome)
megahit \
    -1 "$CORR_R1" \
    -2 "$CORR_R2" \
    --preset sensitive \
    --k-min 27 \
    --k-max 141 \
    --k-step 10 \
    --min-contig-len 500 \
    --min-count 2 \
    --prune-level 3 \
    --bubble-level 2 \
    --merge-level 20,0.95 \
    -t $MEGAHIT_THREADS \
    -m 0.9 \
    -o megahit_optimized

# Verify result
if [ ! -f "megahit_optimized/final.contigs.fa" ]; then
    echo "ERROR: MEGAHIT failed to produce final.contigs.fa"
    exit 1
fi

# Assembly statistics
NUM_CONTIGS=$(grep -c '^>' megahit_optimized/final.contigs.fa)
TOTAL_SIZE=$(awk '/^>/ {if (seqlen) print seqlen; seqlen=0; next} {seqlen += length($0)} END {print seqlen}' megahit_optimized/final.contigs.fa)

echo "✓ Assembly complete"
echo "  Contigs file: megahit_optimized/final.contigs.fa"
echo "  Number of contigs: $NUM_CONTIGS"
echo "  Total size: $(numfmt --to=iec $TOTAL_SIZE 2>/dev/null || echo "$TOTAL_SIZE bp")"


# ============================================================================
# 6. STEP 3: REDUNDANS - REDUNDANCY REMOVAL
# ============================================================================

echo ""
echo "=== STEP 3: Redundans Reduction ==="
echo "Input: megahit_optimized/final.contigs.fa"
echo "Output directory: redundans_output"

# Run Redundans (reduction only, no scaffolding)
redundans.py -v \
    -f megahit_optimized/final.contigs.fa \
    -o redundans_output \
    -t $REDUNDANS_THREADS \
    --identity 0.7 \
    --overlap 0.8 \
    --noscaffolding \
    --nogapclosing

# Find the output file (might be scaffolds.reduced.fa or similar)
if [ -f "redundans_output/scaffolds.reduced.fa" ]; then
    FINAL_ASSEMBLY="redundans_output/scaffolds.reduced.fa"
elif [ -f "redundans_output/redundans_output.scaffolds.reduced.fa" ]; then
    FINAL_ASSEMBLY="redundans_output/redundans_output.scaffolds.reduced.fa"
else
    echo "WARNING: Redundans output not found in expected location"
    echo "Searching for any .fa file in redundans_output/"
    FINAL_ASSEMBLY=$(find redundans_output -name "*.fa" -type f | head -1)
    if [ -z "$FINAL_ASSEMBLY" ]; then
        echo "ERROR: No assembly file found from Redundans"
        exit 1
    fi
fi

echo "✓ Redundancy reduction complete"
echo "  Final assembly: $FINAL_ASSEMBLY"

# Statistics for final assembly
NUM_SCAFFOLDS=$(grep -c '^>' "$FINAL_ASSEMBLY" 2>/dev/null || echo "0")
echo "  Number of scaffolds: $NUM_SCAFFOLDS"

# ============================================================================
# 7. STEP 4: BUSCO - QUALITY ASSESSMENT
# ============================================================================

echo ""
echo "=== STEP 4: BUSCO Evaluation ==="
echo "Input: $FINAL_ASSEMBLY"
echo "Mode: Mammalian lineage (mammalia_odb10)"
echo "Output: busco_megahit_best_redun"

busco \
    -i "$FINAL_ASSEMBLY" \
    -o busco_megahit_best_redun \
    -m genome \
    -c $BUSCO_THREADS \
    -l mammalia_odb10 \
    --download_path "${HOME}/busco_downloads"

echo "✓ BUSCO evaluation complete"
echo "  Results: busco_megahit_best_redun/"

# Extract BUSCO summary
SUMMARY_FILE=$(find busco_megahit_best_redun -name "short_summary*.txt" 2>/dev/null | head -1)
if [ -f "$SUMMARY_FILE" ]; then
    echo ""
    echo "=== BUSCO Summary ==="
    cat "$SUMMARY_FILE"
fi


# ============================================================================
# 8. SUMMARY
# ============================================================================

echo ""
echo "========================================="
echo "PIPELINE COMPLETED SUCCESSFULLY!"
echo "========================================="
echo ""
echo "=== OUTPUT FILES SUMMARY ==="
echo "1. Error-corrected reads:"
echo "   - $CORR_R1"
echo "   - $CORR_R2"
echo ""
echo "2. MEGAHIT assembly:"
echo "   - megahit_optimized/final.contigs.fa"
echo ""
echo "3. Final assembly (after Redundans):"
echo "   - $FINAL_ASSEMBLY"
echo ""
echo "4. BUSCO results:"
echo "   - busco_megahit_best_redun/"
echo ""
echo "5. Log file:"
echo "   - logs/assembly_pipeline_*.log"
echo ""
echo "End time: $(date)"
echo "========================================="
