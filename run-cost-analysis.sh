#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Plasmate Cost Analysis"
echo "======================"
echo ""

# Check dependencies
if ! command -v plasmate &> /dev/null; then
    echo "Error: plasmate not found. Install with: pip install plasmate"
    exit 1
fi

if ! python3 -c "import tiktoken" 2>/dev/null; then
    echo "Installing tiktoken for token counting..."
    pip install tiktoken
fi

URLS_FILE="urls.txt"
RESULTS_DIR="results"
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
RESULTS_FILE="$RESULTS_DIR/cost-analysis-$TIMESTAMP.txt"

mkdir -p "$RESULTS_DIR"

echo "Fetching pages and counting tokens..."
echo ""

TOTAL_HTML_TOKENS=0
TOTAL_SOM_TOKENS=0
COUNT=0

while IFS= read -r url; do
    [[ -z "$url" || "$url" == \#* ]] && continue
    COUNT=$((COUNT + 1))

    HTML=$(curl -sL --max-time 10 "$url" 2>/dev/null || echo "")
    [[ -z "$HTML" ]] && continue

    SOM=$(plasmate som --url "$url" --format json 2>/dev/null || echo "")
    [[ -z "$SOM" ]] && continue

    HTML_TOKENS=$(echo "$HTML" | python3 scripts/count-tokens.py)
    SOM_TOKENS=$(echo "$SOM" | python3 scripts/count-tokens.py)

    TOTAL_HTML_TOKENS=$((TOTAL_HTML_TOKENS + HTML_TOKENS))
    TOTAL_SOM_TOKENS=$((TOTAL_SOM_TOKENS + SOM_TOKENS))

    printf "  [%d] %s  (HTML: %s, SOM: %s)\n" "$COUNT" "$url" "$HTML_TOKENS" "$SOM_TOKENS"
done < "$URLS_FILE"

if [[ "$COUNT" -eq 0 || "$TOTAL_SOM_TOKENS" -eq 0 ]]; then
    echo "Error: No URLs were successfully processed."
    exit 1
fi

AVG_HTML=$((TOTAL_HTML_TOKENS / COUNT))
AVG_SOM=$((TOTAL_SOM_TOKENS / COUNT))

# Generate cost table
generate_report() {
    echo ""
    echo "======================================"
    echo "  COST ANALYSIS REPORT"
    echo "======================================"
    echo ""
    echo "Benchmark Summary:"
    echo "  URLs tested:           $COUNT"
    echo "  Avg HTML tokens/page:  $AVG_HTML"
    echo "  Avg SOM tokens/page:   $AVG_SOM"
    echo "  Compression ratio:     $(echo "scale=1; $AVG_HTML / $AVG_SOM" | bc)x"
    echo ""

    # Model pricing (per 1M input tokens)
    # GPT-4: $30, GPT-4o: $2.50, Claude 3.5 Sonnet: $3, Claude 3 Opus: $15
    echo "┌─────────────────────┬────────────────┬────────────────┬────────────────┬──────────┐"
    echo "│ Model               │  Chrome (HTML)  │ Plasmate (SOM) │    Savings     │ Savings% │"
    echo "├─────────────────────┼────────────────┼────────────────┼────────────────┼──────────┤"

    for model_info in \
        "GPT-4|30.00" \
        "GPT-4o|2.50" \
        "Claude 3.5 Sonnet|3.00" \
        "Claude 3 Opus|15.00"; do

        MODEL_NAME="${model_info%%|*}"
        PRICE="${model_info##*|}"

        for scale_info in "1K|1000" "10K|10000" "100K|100000" "1M|1000000"; do
            SCALE_LABEL="${scale_info%%|*}"
            SCALE_NUM="${scale_info##*|}"

            HTML_COST=$(echo "scale=2; $AVG_HTML * $SCALE_NUM * $PRICE / 1000000" | bc)
            SOM_COST=$(echo "scale=2; $AVG_SOM * $SCALE_NUM * $PRICE / 1000000" | bc)
            SAVED=$(echo "scale=2; $HTML_COST - $SOM_COST" | bc)
            if [[ $(echo "$HTML_COST > 0" | bc) -eq 1 ]]; then
                PCT=$(echo "scale=0; ($SAVED * 100) / $HTML_COST" | bc)
            else
                PCT=0
            fi

            printf "│ %-19s │ \$%12s │ \$%12s │ \$%12s │   %3s%%   │\n" \
                "$MODEL_NAME ($SCALE_LABEL)" "$HTML_COST" "$SOM_COST" "$SAVED" "$PCT"
        done
        echo "├─────────────────────┼────────────────┼────────────────┼────────────────┼──────────┤"
    done

    echo ""
    echo "Prices: GPT-4 \$30/1M tokens, GPT-4o \$2.50/1M, Claude 3.5 Sonnet \$3/1M, Claude 3 Opus \$15/1M"
    echo ""
    echo "Key Takeaway:"
    echo "  At 100K pages/month with GPT-4o, Plasmate saves ~\$$(echo "scale=0; ($AVG_HTML - $AVG_SOM) * 100000 * 2.50 / 1000000" | bc)/month"
    echo ""
}

generate_report | tee "$RESULTS_FILE"

echo "Report saved to: $RESULTS_FILE"
