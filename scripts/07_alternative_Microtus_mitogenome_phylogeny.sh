###  Alternative phylogenetic reconstruction of Microtus mitogenomes script: `scripts/07_alternative_Microtus_mitogenome_phylogeny.sh`
#!/bin/bash
#===============================================================================
# Pipeline: Phylogenetic reconstruction with Gappy Trimming (ClipKIT)
# Purpose: Alternative workflow 
# Dependencies: clipkit v2.1+, mafft, iqtree3
#===============================================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHYLO_DIR="$PROJECT_DIR/results/phylogeny/mitogenomes"

echo "=========================================="
echo "Alternative Pipeline: ClipKIT Trimming"
echo "=========================================="
echo ""

cd "$PHYLO_DIR"

if [[ ! -f "aligned_mitogenomes.fasta" ]]; then
    echo "⚠️  Full alignment not found. Please run 03_build_mitogenome_tree.sh first."
    exit 1
fi

#===============================================================================
# STEP 1: Trim alignment with ClipKIT
#===============================================================================
echo "[1/2] Trimming poorly aligned positions with ClipKIT..."

clipkit aligned_mitogenomes.fasta \
    -g 0.0001 -m gappy -eo \
    -o aligned_mitogenomes_trimmed.fasta

TRIM_LEN=$(awk '!/^>/ {len+=length($0)} END {print len}' aligned_mitogenomes_trimmed.fasta)
FULL_LEN=$(awk '!/^>/ {len+=length($0)} END {print len}' aligned_mitogenomes.fasta)
REDUCED=$(awk "BEGIN {printf \"%.1f\", (1 - $TRIM_LEN/$FULL_LEN)*100}")

echo "✓ Trimmed: $FULL_LEN bp → $TRIM_LEN bp (reduced by ${REDUCED}%)"
echo ""

#===============================================================================
# STEP 2: Build Tree on Trimmed Alignment
#===============================================================================
echo "[2/2] Reconstructing ML tree on trimmed alignment..."

iqtree3 -s aligned_mitogenomes_trimmed.fasta \
    -o Arvicola_amphibius \
    -m MFP -B 1000 -alrt 1000 -abayes \
    -T 8 -pre mitogenome_tree_trimmed

BEST_MODEL=$(grep "Best-fit model" mitogenome_tree_trimmed.iqtree | head -1)
echo "Selected model (trimmed): $BEST_MODEL"

echo ""
echo "=========================================="
echo "ALTERNATIVE PIPELINE COMPLETE"
echo "=========================================="
echo "Output files:"
echo "  - Trimmed alignment: aligned_mitogenomes_trimmed.fasta"
echo "  - Trimmed tree:      mitogenome_tree_trimmed.treefile"
echo "=========================================="
echo "📝 Note: Compare topology with mitogenome_tree_full.treefile"