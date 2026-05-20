### Main script: `scripts/01_preprocess_ancient_dna.sh`
#!/bin/bash
#===============================================================================
# Pipeline: Ancient DNA Preprocessing
# Tools: fastp + AdapterRemoval with collapsing
#===============================================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAW_DIR="$PROJECT_DIR/raw_data"
PREPROC_DIR="$PROJECT_DIR/results/preprocessing"

mkdir -p "$PREPROC_DIR"/{01_fastp,02_adapterremoval,fastqc_reports}

echo "=========================================="
echo "Ancient DNA Preprocessing Pipeline"
echo "=========================================="
echo ""

#===============================================================================
# STEP 1: Fastp - Poly-G trimming
#===============================================================================

echo "[1/2] Removing poly-G tails with fastp..."

fastp \
  -i "$RAW_DIR/miurus_R1.fastq.gz" \
  -I "$RAW_DIR/miurus_R2.fastq.gz" \
  -o "$PREPROC_DIR/01_fastp/01_miurus_R1.nopolyG.fastq.gz" \
  -O "$PREPROC_DIR/01_fastp/01_miurus_R2.nopolyG.fastq.gz" \
  --trim_poly_g \
  --poly_g_min_len 10 \
  --length_required 25 \
  --thread 4 \
  -h "$PREPROC_DIR/01_fastp/01_fastp_report.html" \
  -j "$PREPROC_DIR/01_fastp/01_fastp_report.json"

echo "✓ Fastp complete"
echo ""

#===============================================================================
# STEP 2: AdapterRemoval - Adapter trimming and collapsing
#===============================================================================

echo "[2/2] Running AdapterRemoval with collapsing..."

cd "$PREPROC_DIR/02_adapterremoval"

AdapterRemoval \
  --file1 ../01_fastp/01_miurus_R1.nopolyG.fastq.gz \
  --file2 ../01_fastp/01_miurus_R2.nopolyG.fastq.gz \
  --collapse \
  --minlength 25 \
  --trimns \
  --trimqualities \
  --minquality 20 \
  --gzip \
  --outputcollapsed 02_miurus.collapsed.fastq.gz \
  --output1 02_miurus_R1.trimmed.fastq.gz \
  --output2 02_miurus_R2.trimmed.fastq.gz \
  --threads 8 \
  > 02_adapterremoval.log 2>&1

# Quality check
echo "✓ AdapterRemoval complete"
echo ""
echo "Checking collapsed reads quality..."
seqkit stats 02_miurus.collapsed.fastq.gz

echo ""
echo "=========================================="
echo "PREPROCESSING COMPLETE"
echo "=========================================="
echo "Output files:"
echo "  - Collapsed: 02_miurus.collapsed.fastq.gz"
echo "  - R1 trimmed: 02_miurus_R1.trimmed.fastq.gz"
echo "  - R2 trimmed: 02_miurus_R2.trimmed.fastq.gz"
echo "  - Log: 02_adapterremoval.log"
echo ""
echo "Ready for Kraken2 classification!"