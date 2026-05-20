### Alternative script without dating: `scripts/09_cytb_ml_tree.sh`
#!/bin/bash
#===============================================================================
# Pipeline: Maximum Likelihood phylogeny of Microtus cytochrome b (no dating)
# Method: IQ-TREE3 with ModelFinder
# Dependencies: mafft, trimal, iqtree3
#===============================================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CYTB_DIR="$PROJECT_DIR/results/phylogeny/cytb_analysis"

mkdir -p "$CYTB_DIR"
cd "$CYTB_DIR"

echo "=========================================="
echo "Cytochrome b ML Phylogeny Pipeline"
echo "=========================================="
echo ""

#===============================================================================
# STEP 1: Alignment and trimming
#===============================================================================

if [[ ! -f "aligned_cytb_clean.fasta" ]]; then
    echo "[1/3] Aligning and trimming sequences..."
    
    mafft --auto --thread 8 --reorder --adjustdirection \
        all_cytb_combined.fasta > aligned_cytb.fasta
    
    trimal -in aligned_cytb.fasta -out aligned_cytb_clean.fasta -automated1
    
    echo "✓ Alignment complete: $(grep -c '^>' aligned_cytb_clean.fasta) taxa"
else
    echo "[1/3] Using existing trimmed alignment"
fi

#===============================================================================
# STEP 2: Build ML tree with IQ-TREE3
#===============================================================================

echo "[2/3] Reconstructing ML tree with IQ-TREE3..."

iqtree3 -s aligned_cytb_clean.fasta \
    -o AF163895.1 \  # Stenocranius gregalis as outgroup
    -m MFP -B 1000 -alrt 1000 \
    -T 8 -pre cytb_tree_ml

BEST_MODEL=$(grep "Best-fit model" cytb_tree_ml.iqtree | head -1)
echo "Selected model: $BEST_MODEL"

#===============================================================================
# STEP 3: Cleanup and summary
#===============================================================================

echo "[3/3] Finalizing results..."

# Optional: rename tips for readability (using provided Python script)
if [[ -f "rename_tree.py" ]]; then
    python3 rename_tree.py
    echo "✓ Tree labels cleaned"
fi

echo ""
echo "=========================================="
echo "PIPELINE COMPLETE"
echo "=========================================="
echo "Output files:"
echo "  - Tree:      cytb_tree_ml_named.treefile"
echo "  - Stats:     cytb_tree_ml.iqtree"
echo "  - Alignment: aligned_cytb_clean.fasta"
echo ""
echo "Ready for visualization in FigTree!"