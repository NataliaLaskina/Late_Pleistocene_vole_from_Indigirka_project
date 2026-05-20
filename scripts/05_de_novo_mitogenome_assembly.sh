###  De novo mitogenome assembly script: `scripts/05_de_novo_mitogenome_assembly.sh`
#!/bin/bash
#===============================================================================
# Pipeline: De novo mitogenome assembly using MitoZ
# Species: Microtus mexicanus and M. oregoni
# Method: MitoZ with MEGAHIT assembler
# Dependencies: sra-tools v2.11.3, mitoz v4.0, megahit
#===============================================================================

set -euo pipefail

#===============================================================================
# CONFIGURATION
#===============================================================================

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTDIR="$PROJECT_DIR/results/mitoz_analysis"
PHYLO_DIR="$PROJECT_DIR/results/phylogeny/mitogenomes"

# Create directories
mkdir -p "$OUTDIR"/{mexicanus_raw,oregoni_raw}
mkdir -p "$PHYLO_DIR"

echo "=========================================="
echo "MitoZ Mitogenome Assembly Pipeline"
echo "=========================================="
echo ""

#===============================================================================
# STEP 1: Download and convert SRA data
#===============================================================================

echo "[1/4] Downloading SRA data..."

# M. mexicanus
cd "$OUTDIR/mexicanus_raw"
if [[ ! -f "SRR26062149/SRR26062149.sra" ]]; then
    echo "Downloading M. mexicanus (SRR26062149)..."
    prefetch --max-size 100G SRR26062149
fi

# M. oregoni (two runs)
cd "$OUTDIR/oregoni_raw"
if [[ ! -f "SRR5176499/SRR5176499.sra" ]] || [[ ! -f "SRR5487548/SRR5487548.sra" ]]; then
    echo "Downloading M. oregoni (SRR5176499, SRR5487548)..."
    prefetch --max-size 100G SRR5176499
    prefetch --max-size 100G SRR5487548
fi

echo "✓ SRA data downloaded"
echo ""

#===============================================================================
# STEP 2: Convert SRA to FASTQ
#===============================================================================

echo "[2/4] Converting SRA to FASTQ..."

# M. mexicanus
cd "$OUTDIR/mexicanus_raw/SRR26062149"
if [[ ! -f "SRR26062149_1.fastq.gz" ]]; then
    echo "Converting M. mexicanus..."
    fastq-dump --split-files --gzip SRR26062149.sra
fi

# M. oregoni (combine two runs)
cd "$OUTDIR/oregoni_raw"
if [[ ! -f "oregoni_combined_1.fastq.gz" ]]; then
    echo "Converting and combining M. oregoni..."
    cd SRR5176499
    fastq-dump --split-files --gzip --maxSpotId 5000000 SRR5176499.sra
    cd ../SRR5487548
    fastq-dump --split-files --gzip --maxSpotId 5000000 SRR5487548.sra
    cd ..
    
    # Combine both runs
    cat SRR5176499/SRR5176499_1.fastq.gz SRR5487548/SRR5487548_1.fastq.gz > oregoni_combined_1.fastq.gz
    cat SRR5176499/SRR5176499_2.fastq.gz SRR5487548/SRR5487548_2.fastq.gz > oregoni_combined_2.fastq.gz
fi

echo "✓ FASTQ files ready"
echo ""

#===============================================================================
# STEP 3: Assemble mitogenomes with MitoZ
#===============================================================================

echo "[3/4] Assembling mitogenomes with MitoZ..."

# M. mexicanus
cd "$OUTDIR/mexicanus_raw/SRR26062149"
if [[ ! -f "../mexicanus_result/mexicanus.megahit.result/mexicanus.megahit.mitogenome.fa" ]]; then
    echo "Assembling M. mexicanus..."
    mitoz assemble \
        --fq1 SRR26062149_1.fastq.gz \
        --fq2 SRR26062149_2.fastq.gz \
        --clade Chordata \
        --requiring_taxa "Chordata" \
        --outprefix mexicanus \
        --thread_number 16 \
        --workdir "$OUTDIR/mexicanus_raw/mexicanus_result" \
        --assembler megahit
fi

# M. oregoni
cd "$OUTDIR/oregoni_raw"
if [[ ! -f "oregoni_result/oregoni.megahit.result/oregoni.megahit.mitogenome.fa" ]]; then
    echo "Assembling M. oregoni..."
    mitoz assemble \
        --fq1 oregoni_combined_1.fastq.gz \
        --fq2 oregoni_combined_2.fastq.gz \
        --clade Chordata \
        --requiring_taxa "Chordata" \
        --outprefix oregoni \
        --thread_number 16 \
        --workdir "$OUTDIR/oregoni_raw/oregoni_result" \
        --assembler megahit
fi

echo "✓ Assembly complete"
echo ""

#===============================================================================
# STEP 4: Process and validate results
#===============================================================================

echo "[4/4] Processing final sequences..."

# M. mexicanus
MEX_FASTA="$OUTDIR/mexicanus_raw/mexicanus_result/mexicanus.megahit.result/mexicanus.megahit.mitogenome.fa"
MEX_FINAL="$PHYLO_DIR/M_mexicanus.fasta"

if [[ -f "$MEX_FASTA" ]]; then
    cp "$MEX_FASTA" "$MEX_FINAL"
    # Fix header
    sed -i '1s/>.*/>Microtus_mexicanus/' "$MEX_FINAL"
    MEX_LEN=$(grep -v '^>' "$MEX_FINAL" | tr -d '\n' | wc -c)
    echo "  M. mexicanus: $MEX_LEN bp"
fi

# M. oregoni
ORE_FASTA="$OUTDIR/oregoni_raw/oregoni_result/oregoni.megahit.result/oregoni.megahit.mitogenome.fa"
ORE_FINAL="$PHYLO_DIR/M_oregoni.fasta"

if [[ -f "$ORE_FASTA" ]]; then
    cp "$ORE_FASTA" "$ORE_FINAL"
    # Fix header (remove k-mer contig name, keep only species)
    {
        echo ">Microtus_oregoni"
        grep -v '^>' "$ORE_FINAL"
    } > /tmp/oregoni_temp.fasta && mv /tmp/oregoni_temp.fasta "$ORE_FINAL"
    
    ORE_LEN=$(grep -v '^>' "$ORE_FINAL" | tr -d '\n' | wc -c)
    echo "  M. oregoni: $ORE_LEN bp"
fi

echo ""
echo "=========================================="
echo "ASSEMBLY SUMMARY"
echo "=========================================="
echo "M. mexicanus: $(grep -v '^>' "$MEX_FINAL" | tr -d '\n' | wc -c) bp"
echo "M. oregoni:   $(grep -v '^>' "$ORE_FINAL" | tr -d '\n' | wc -c) bp"
echo "=========================================="
echo ""
echo "Output files:"
echo "  - $MEX_FINAL"
echo "  - $ORE_FINAL"
echo ""
echo "Pipeline completed successfully! ✓"
```