### **`scripts/kraken_build/download_kraken.sh`**
#!/usr/bin/env bash
IFS=$'\n'
DB="$1"
SUMMARY="$2"

LOG="process_all.log"
ERRLOG="failed_all.log"

: > "$LOG"
: > "$ERRLOG"

for LINE in $(cat "$SUMMARY" ); do

    # split line into fields (tab-separated)
    GCF=$(echo "$LINE" | cut -f1)
    TAXID=$(echo "$LINE" | cut -f6)
    FTP=$(echo "$LINE" | cut -f20)

    echo "===== $GCF =====" | tee -a "$LOG"

    # skip empty/broken lines
    if [[ -z "$GCF" || -z "$FTP" || "$FTP" == "na" ]]; then
        echo "ERROR: bad line or missing FTP" | tee -a "$LOG" "$ERRLOG"
        continue
    fi

    BASENAME=$(basename "$FTP")
    FILE="${BASENAME}_genomic.fna.gz"
    URL="${FTP}${FILE}"

    echo "Downloading: $URL (taxid=$TAXID)" | tee -a "$LOG"

    # --- download ---
    wget -q "$URL" -O "${GCF}.fna.gz"
    if [[ $? -ne 0 || ! -s "${GCF}.fna.gz" ]]; then
        echo "ERROR: download failed" | tee -a "$LOG" "$ERRLOG"
        rm -f "${GCF}.fna.gz"
        continue
    fi

    # --- process + rewrite headers (streaming) ---
    gunzip -c "${GCF}.fna.gz" | \
    awk -v taxid="$TAXID" '
        /^>/ { print ">kraken:taxid|"taxid"|"substr($0,2); next }
        { print }
    ' > "${GCF}.kraken.fna"

    if [[ $? -ne 0 || ! -s "${GCF}.kraken.fna" ]]; then
        echo "ERROR: processing failed" | tee -a "$LOG" "$ERRLOG"
        rm -f "${GCF}.fna.gz" "${GCF}.kraken.fna"
        continue
    fi

    # --- add to kraken ---
    k2 add-to-library --file "${GCF}.kraken.fna" --db "$DB"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: kraken add failed" | tee -a "$LOG" "$ERRLOG"
        continue
    fi

    echo "SUCCESS: $GCF added" | tee -a "$LOG"

    # cleanup
    rm -f "${GCF}.fna.gz" "${GCF}.kraken.fna"

done