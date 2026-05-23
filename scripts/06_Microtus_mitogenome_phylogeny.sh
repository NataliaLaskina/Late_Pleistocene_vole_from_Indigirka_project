###  Phylogenetic reconstruction of Microtus mitogenomes script: `scripts/06_Microtus_mitogenome_phylogeny.sh`
#!/bin/bash
#===============================================================================
# Pipeline: Phylogenetic reconstruction of Microtus mitogenomes (FULL alignment)
# Method: MAFFT alignment + IQ-TREE3 Maximum Likelihood
# Dependencies: efetch, mafft v7.526+, iqtree3 v3+
#===============================================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHYLO_DIR="$PROJECT_DIR/results/phylogeny/mitogenomes"

mkdir -p "$PHYLO_DIR"

echo "=========================================="
echo "Microtus Mitogenome Phylogeny Pipeline"
echo "=========================================="
echo ""

#===============================================================================
# STEP 1: Combine sequences and standardize headers
#===============================================================================

# Download from NCBI GenBank
# Search: "Microtus mitochondrial"
# Filter: complete genome + voucher specimens
# Added: ancient vole mitogenome + newly assembled M. mexicanus and M. oregoni + Arvicola amphibius

echo "[1/4] Combining FASTA files and cleaning headers..."

cd "$PHYLO_DIR"
cat *.fasta > all_mitogenomes_combined.fasta

# Standardize headers: extract genus_species, replace spaces with underscores
awk '
/^>/ {
    if (match($0, /[A-Z][a-z]+_[a-z]+/)) {
        sub(/^[^>]*>/, ">" substr($0, RSTART, RLENGTH))
    } else {
        # Fallback for GenBank headers
        gsub(/ /, "_", $0)
    }
    print
    next
}
{ print }
' all_mitogenomes_combined.fasta > all_mitogenomes_clean.fasta

# Fix specific problematic headers if needed
sed -i 's/^>Unknown_.*/>Microtus_egorovi_Indigirka/' all_mitogenomes_clean.fasta
sed -i 's/^>Arvicola_amphibius.*/>Arvicola_amphibius/' all_mitogenomes_clean.fasta

TOTAL_SEQS=$(grep -c "^>" all_mitogenomes_clean.fasta)
echo "✓ Combined $TOTAL_SEQS sequences"
echo ""

#===============================================================================
# STEP 2: Multiple Sequence Alignment
#===============================================================================
echo "[2/4] Aligning sequences with MAFFT..."

mafft --auto --thread 8 --reorder --adjustdirection \
    all_mitogenomes_clean.fasta > aligned_mitogenomes.fasta

ALIGN_LEN=$(awk '!/^>/ {len+=length($0)} END {print len}' aligned_mitogenomes.fasta)
echo "✓ Alignment complete: ~$((ALIGN_LEN/26)) bp per sequence"
echo ""

#===============================================================================
# STEP 3: Build Phylogenetic Tree (Full Alignment)
#===============================================================================
echo "[3/4] Reconstructing ML tree with IQ-TREE3..."

iqtree3 -s aligned_mitogenomes.fasta \
    -o Arvicola_amphibius \
    -m MFP -B 1000 -alrt 1000 -abayes \
    -T 8 -pre mitogenome_tree_full

echo "✓ Tree built successfully"
echo ""

#===============================================================================
# STEP 4: Extract model & cleanup
#===============================================================================
echo "[4/4] Finalizing results..."

BEST_MODEL=$(grep "Best-fit model" mitogenome_tree_full.iqtree | head -1)
echo "Selected model: $BEST_MODEL"

# Remove intermediate combined file
rm -f all_mitogenomes_combined.fasta

echo ""
echo "=========================================="
echo "PIPELINE COMPLETE"
echo "=========================================="
echo "Output files:"
echo "  - Alignment: aligned_mitogenomes.fasta"
echo "  - Tree:      mitogenome_tree_full.treefile"
echo "  - Stats:     mitogenome_tree_full.iqtree"
echo "=========================================="
echo "Ready for visualization in FigTree/Dendroscope!"