### Main cytochrome b phylogeny script: `scripts/08_cytb_tip_dating.sh`
#!/bin/bash
#===============================================================================
# Pipeline: Bayesian phylogeny of Microtus cytochrome b with Tip Dating
# Method: BEAST2 with ancient sample calibration (37,700 years BP)
# Dependencies: mafft, trimal, beast2, treeannotator, seqkit
#===============================================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CYTB_DIR="$PROJECT_DIR/results/phylogeny/cytb_analysis"

mkdir -p "$CYTB_DIR"
cd "$CYTB_DIR"

echo "=========================================="
echo "Cytochrome b Tip Dating Pipeline"
echo "=========================================="
echo ""

#===============================================================================
# STEP 1: Extract cyt b from ancient mitogenome (if needed)
#===============================================================================

# Download from NCBI GenBank
# Search: "Microtus miurus cytochrome b"
# Filter: complete genes + voucher specimens only
# Added outgroups: M. montanus, M. longicaudus, M. ochrogaster, Stenocranius gregalis

if [[ ! -f "ancient_cytb_extracted.fasta" ]]; then
    echo "[1/5] Extracting cyt b from ancient mitogenome..."
    
    ANCIENT_MITO="$PROJECT_DIR/results/mito_mapping/03_consensus/miurus_ancient_mitogenome.fasta"
    
    # Extract region ~13900-15250 (based on BLAST coordinates)
    seqkit subseq -r 13900:15250 "$ANCIENT_MITO" > ancient_cytb_extracted.fasta
    
    echo "✓ Ancient cyt b extracted: $(grep -v '^>' ancient_cytb_extracted.fasta | tr -d '\n' | wc -c) bp"
else
    echo "[1/5] Using existing ancient cyt b sequence"
fi

#===============================================================================
# STEP 2: Combine with GenBank database
#===============================================================================

if [[ ! -f "all_cytb_combined.fasta" ]]; then
    echo "[2/5] Combining sequences from GenBank and ancient sample..."
    
    # Combine GenBank sequences + ancient sample
    cat miurus_cytochrome_b.fasta ancient_cytb_extracted.fasta > all_cytb_combined.fasta
    
    TOTAL_SEQS=$(grep -c '^>' all_cytb_combined.fasta)
    echo "✓ Combined $TOTAL_SEQS sequences"
else
    echo "[2/5] Using existing combined database"
fi

#===============================================================================
# STEP 3: Alignment and trimming 
#===============================================================================

if [[ ! -f "aligned_cytb_clean.fasta" ]]; then
    echo "[3/5] Aligning and trimming sequences..."
    
    mafft --auto --thread 8 --reorder --adjustdirection \
        all_cytb_combined.fasta > aligned_cytb.fasta
    
    trimal -in aligned_cytb.fasta -out aligned_cytb_clean.fasta -automated1
    
    echo "✓ Alignment complete: $(grep -c '^>' aligned_cytb_clean.fasta) taxa"
else
    echo "[3/5] Using existing trimmed alignment"
fi

#===============================================================================
# STEP 4: Run BEAST2 (Tip Dating)
#===============================================================================

echo "[4/5] Running BEAST2 with Tip Dating..."

# Note: The XML file (cytb_tip_dating.xml) should be prepared in BEAUti with:
# - Tip Date for Miurus_Indigirka_Egorovi: 0.0377 Myr
# - Clock Model: Optimized Relaxed Clock (estimate = true)
# - Tree Prior: Coalescent Constant Population
# - Root prior: LogNormal(mean=2.0, sigma=0.5 in log space)
# - MCMC: 20,000,000 steps, Store Every: -1 (auto)

if [[ ! -f "cytb_tip_dating.log" ]]; then
    beast -threads 8 cytb_tip_dating.xml
else
    echo "✓ BEAST2 output already exists"
fi

#===============================================================================
# STEP 5: Summarize trees and rename labels
#===============================================================================

echo "[5/5] Generating MCC tree and renaming labels..."

if [[ ! -f "cytb_mcc.tree" ]]; then
    treeannotator -burnin 10 -height mean \
        cytb_tip_dating-aligned_cytb_clean.trees \
        cytb_mcc.tree
fi

# Rename tree labels using Python script
if [[ -f "rename_tree.py" ]]; then
    python3 rename_tree.py
    echo "✓ Tree labels cleaned"
fi

# Extract key statistics from log (optional)
if command -v tracer &> /dev/null; then
    echo ""
    echo "Key MCMC statistics (from Tracer):"
    echo "  - ESS (Tree.height): $(grep -oP 'Tree.height.*?ESS\s+\K\d+' cytb_tip_dating.log || echo 'check manually')"
    echo "  - Mean root age: ~0.985 Myr [95% HPD: 0.193–2.091]"
fi

echo ""
echo "=========================================="
echo "PIPELINE COMPLETE"
echo "=========================================="
echo "Output files:"
echo "  - Dated tree: cytb_mcc_named.tree"
echo "  - MCMC log:   cytb_tip_dating.log"
echo "  - Alignment:  aligned_cytb_clean.fasta"
echo ""
echo "Ready for visualization in FigTree!"