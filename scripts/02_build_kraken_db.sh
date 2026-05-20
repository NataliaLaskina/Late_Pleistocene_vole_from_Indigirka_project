### Kraken2 scripts: `scripts/02_build_kraken_db.sh`
#!/bin/bash
#===============================================================================
# Pipeline: Custom Kraken2 Database Construction
# Note: Uses custom script for Bacteria, Viruses, and Fungi due to NCBI server issues.
#===============================================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_DIR="$PROJECT_DIR/databases/kraken2_miurus"
SCRIPTS_DIR="$PROJECT_DIR/scripts/kraken_build"

# The custom script path (assumed to be in scripts/kraken_build)
CUSTOM_SCRIPT="$SCRIPTS_DIR/download_kraken.sh"

mkdir -p "$DB_DIR"
cd "$DB_DIR"

echo "=========================================="
echo "Kraken2 Custom Database Builder"
echo "=========================================="
echo ""

#===============================================================================
# STEP 1: Download taxonomy
#===============================================================================

echo "[1/7] Downloading NCBI taxonomy..."

kraken2-build --download-taxonomy --db . --use-ftp

echo "✓ Taxonomy downloaded"
echo ""

#===============================================================================
# STEP 2: Download human genome
#===============================================================================

echo "[2/7] Downloading human genome..."

kraken2-build --download-library human --db . --use-ftp --threads 4

echo "✓ Human genome downloaded"
echo ""

#===============================================================================
# STEP 3: Download Bacteria (custom script)
#===============================================================================

echo "[3/7] Downloading bacterial reference genomes..."

cd "$SCRIPTS_DIR"

# Download assembly summary
wget -O assembly_summary.txt \
  https://ftp.ncbi.nlm.nih.gov/genomes/refseq/bacteria/assembly_summary.txt

# Filter reference genomes
grep -v "^#" assembly_summary.txt | \
  awk -F'\t' '$5=="reference genome" && $20!=""' > bacteria_reference.tsv

# Run the custom download script
bash "$CUSTOM_SCRIPT" "$DB_DIR" bacteria_reference.tsv

echo "✓ Bacterial genomes downloaded"
echo ""

#===============================================================================
# STEP 4: Download Viruses (Custom Script)
#===============================================================================

echo "[4/7] Downloading Viral genomes (Custom Script)..."

# Download viral summary
wget -q -O assembly_summary_viral.txt \
  https://ftp.ncbi.nlm.nih.gov/genomes/refseq/viral/assembly_summary.txt

# Filter (take all with valid FTP path)
grep -v "^#" assembly_summary_viral.txt | \
  awk -F'\t' '$20!="na"' > viral_reference.tsv

# Run the custom downloader script
bash "$CUSTOM_SCRIPT" "$DB_DIR" viral_reference.tsv

echo "✓ Viral genomes downloaded"
echo ""

#===============================================================================
# STEP 5: Download Fungi (Custom Script)
#===============================================================================

echo "[5/7] Downloading Fungal genomes (Custom Script)..."

# Download fungal summary
wget -q -O assembly_summary_fungi.txt \
  https://ftp.ncbi.nlm.nih.gov/genomes/refseq/fungi/assembly_summary.txt

# Filter (take all with valid FTP path)
grep -v "^#" assembly_summary_fungi.txt | \
  awk -F'\t' '$20!="na"' > fungi_reference.tsv

# Run the SAME custom downloader script
bash "$CUSTOM_SCRIPT" "$DB_DIR" fungi_reference.tsv

echo "✓ Fungal genomes downloaded"
echo ""

#===============================================================================
# STEP 6: Add Microtus reference genomes
#===============================================================================

echo "[6/7] Adding Microtus reference genomes..."

GENOMES_DIR="$PROJECT_DIR/databases/genomes"

kraken2-build --add-to-library "$GENOMES_DIR/M_ochrogaster/GCF_000317375.1.fna" --db .
kraken2-build --add-to-library "$GENOMES_DIR/M_oregoni/GCF_018167655.1.fna" --db .
kraken2-build --add-to-library "$GENOMES_DIR/M_agrestis/GCA_902806775.1.fna" --db .
kraken2-build --add-to-library "$GENOMES_DIR/M_arvalis/GCA_044665705.1.fna" --db .

echo "✓ Microtus genomes added"
echo ""

#===============================================================================
# STEP 7: Build index
#===============================================================================

echo "[7/7] Building Kraken2 index (this may take ~4 hours)..."

kraken2-build --build --db . --threads 16 --kmer-len 35

echo "✓ Database built successfully"
echo ""

# Check size
DB_SIZE=$(du -sh . | cut -f1)
echo "=========================================="
echo "DATABASE COMPLETE"
echo "=========================================="
echo "Size: $DB_SIZE"
echo "Location: $DB_DIR"
echo ""
echo "Ready for classification!"