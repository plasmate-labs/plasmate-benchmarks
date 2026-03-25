#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Plasmate Benchmark Suite"
echo "========================"
echo ""

# Check plasmate is installed
if ! command -v plasmate &> /dev/null; then
    echo "Error: plasmate not found. Install with: pip install plasmate"
    exit 1
fi

# Check Python and tiktoken
if ! python3 -c "import tiktoken" 2>/dev/null; then
    echo "Installing tiktoken for token counting..."
    pip install tiktoken
fi

URLS_FILE="urls.txt"
RESULTS_DIR="results"
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
RESULTS_FILE="$RESULTS_DIR/benchmark-$TIMESTAMP.json"

mkdir -p "$RESULTS_DIR"

URL_COUNT=$(grep -cv '^\s*$\|^\s*#' "$URLS_FILE" || true)
echo "Running benchmark against $URL_COUNT URLs..."
echo ""

TOTAL_HTML_TOKENS=0
TOTAL_SOM_TOKENS=0
COUNT=0
FIRST=1

echo "[" > "$RESULTS_FILE"

while IFS= read -r url; do
    [[ -z "$url" || "$url" == \#* ]] && continue
    COUNT=$((COUNT + 1))

    # Get HTML
    HTML=$(curl -sL --max-time 10 "$url" 2>/dev/null || echo "")
    if [[ -z "$HTML" ]]; then
        echo "  [$COUNT] SKIP $url (fetch failed)"
        continue
    fi

    # Get SOM
    SOM=$(plasmate som --url "$url" --format json 2>/dev/null || echo "")
    if [[ -z "$SOM" ]]; then
        echo "  [$COUNT] SKIP $url (plasmate failed)"
        continue
    fi

    # Count tokens
    HTML_TOKENS=$(echo "$HTML" | python3 scripts/count-tokens.py)
    SOM_TOKENS=$(echo "$SOM" | python3 scripts/count-tokens.py)

    if [[ "$SOM_TOKENS" -gt 0 ]]; then
        RATIO=$(echo "scale=1; $HTML_TOKENS / $SOM_TOKENS" | bc)
    else
        RATIO="N/A"
    fi

    TOTAL_HTML_TOKENS=$((TOTAL_HTML_TOKENS + HTML_TOKENS))
    TOTAL_SOM_TOKENS=$((TOTAL_SOM_TOKENS + SOM_TOKENS))

    echo "  [$COUNT] ${RATIO}x  $url  (HTML: $HTML_TOKENS, SOM: $SOM_TOKENS)"

    if [[ $FIRST -eq 1 ]]; then
        FIRST=0
    else
        echo "," >> "$RESULTS_FILE"
    fi
    echo "  {\"url\": \"$url\", \"html_tokens\": $HTML_TOKENS, \"som_tokens\": $SOM_TOKENS, \"ratio\": $RATIO}" >> "$RESULTS_FILE"

done < "$URLS_FILE"

echo "" >> "$RESULTS_FILE"
echo "]" >> "$RESULTS_FILE"

echo ""
echo "========================"
echo "Results:"
echo "  URLs tested: $COUNT"
echo "  Total HTML tokens: $TOTAL_HTML_TOKENS"
echo "  Total SOM tokens: $TOTAL_SOM_TOKENS"
if [[ "$TOTAL_SOM_TOKENS" -gt 0 ]]; then
    OVERALL=$(echo "scale=1; $TOTAL_HTML_TOKENS / $TOTAL_SOM_TOKENS" | bc)
    echo "  Overall compression: ${OVERALL}x"
fi
echo ""
echo "Results saved to: $RESULTS_FILE"
