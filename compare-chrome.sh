#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Plasmate vs Chrome Headless Comparison"
echo "======================================="
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

# Find Chrome
CHROME=""
for candidate in \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/usr/bin/google-chrome" \
    "/usr/bin/google-chrome-stable" \
    "/usr/bin/chromium" \
    "/usr/bin/chromium-browser" \
    "/snap/bin/chromium"; do
    if [[ -x "$candidate" ]]; then
        CHROME="$candidate"
        break
    fi
done

if [[ -z "$CHROME" ]]; then
    echo "Error: Chrome/Chromium not found. Install Chrome or set CHROME_PATH."
    exit 1
fi
echo "Using Chrome: $CHROME"

# Detect OS for memory measurement
IS_LINUX=false
IS_MACOS=false
if [[ "$(uname)" == "Linux" ]]; then
    IS_LINUX=true
elif [[ "$(uname)" == "Darwin" ]]; then
    IS_MACOS=true
fi

URLS_FILE="urls.txt"
RESULTS_DIR="results"
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
RESULTS_FILE="$RESULTS_DIR/chrome-comparison-$TIMESTAMP.txt"
MAX_URLS="${1:-10}"  # Default to 10 URLs for speed; pass 'all' or a number

mkdir -p "$RESULTS_DIR"

# Collect URLs
URLS=()
while IFS= read -r url; do
    [[ -z "$url" || "$url" == \#* ]] && continue
    URLS+=("$url")
done < "$URLS_FILE"

if [[ "$MAX_URLS" == "all" ]]; then
    MAX_URLS=${#URLS[@]}
fi

echo "Testing $MAX_URLS URLs (pass 'all' to test all ${#URLS[@]})"
echo ""

# Measure a single run with timing and memory
measure_chrome() {
    local url="$1"
    local tmpfile
    tmpfile=$(mktemp)

    local start end elapsed mem_kb output_size tokens

    if $IS_MACOS; then
        start=$(python3 -c "import time; print(time.time())")
        command time -l "$CHROME" --headless=new --dump-dom --disable-gpu --no-sandbox "$url" > "$tmpfile" 2>/tmp/chrome-time-stderr || true
        end=$(python3 -c "import time; print(time.time())")
        elapsed=$(echo "$end - $start" | bc)
        mem_kb=$(grep "maximum resident set size" /tmp/chrome-time-stderr 2>/dev/null | awk '{print $1}' || echo "0")
        # macOS reports bytes, convert to KB
        mem_kb=$((mem_kb / 1024))
    elif $IS_LINUX; then
        start=$(python3 -c "import time; print(time.time())")
        /usr/bin/time -v "$CHROME" --headless=new --dump-dom --disable-gpu --no-sandbox "$url" > "$tmpfile" 2>/tmp/chrome-time-stderr || true
        end=$(python3 -c "import time; print(time.time())")
        elapsed=$(echo "$end - $start" | bc)
        mem_kb=$(grep "Maximum resident set size" /tmp/chrome-time-stderr 2>/dev/null | awk '{print $NF}' || echo "0")
    else
        start=$(python3 -c "import time; print(time.time())")
        "$CHROME" --headless=new --dump-dom --disable-gpu --no-sandbox "$url" > "$tmpfile" 2>/dev/null || true
        end=$(python3 -c "import time; print(time.time())")
        elapsed=$(echo "$end - $start" | bc)
        mem_kb=0
    fi

    output_size=$(wc -c < "$tmpfile" | tr -d ' ')
    tokens=$(python3 scripts/count-tokens.py < "$tmpfile")
    rm -f "$tmpfile"

    echo "$elapsed $mem_kb $output_size $tokens"
}

measure_plasmate() {
    local url="$1"
    local tmpfile
    tmpfile=$(mktemp)

    local start end elapsed mem_kb output_size tokens

    if $IS_MACOS; then
        start=$(python3 -c "import time; print(time.time())")
        command time -l plasmate fetch "$url" > "$tmpfile" 2>/tmp/plasmate-time-stderr || true
        end=$(python3 -c "import time; print(time.time())")
        elapsed=$(echo "$end - $start" | bc)
        mem_kb=$(grep "maximum resident set size" /tmp/plasmate-time-stderr 2>/dev/null | awk '{print $1}' || echo "0")
        mem_kb=$((mem_kb / 1024))
    elif $IS_LINUX; then
        start=$(python3 -c "import time; print(time.time())")
        /usr/bin/time -v plasmate fetch "$url" > "$tmpfile" 2>/tmp/plasmate-time-stderr || true
        end=$(python3 -c "import time; print(time.time())")
        elapsed=$(echo "$end - $start" | bc)
        mem_kb=$(grep "Maximum resident set size" /tmp/plasmate-time-stderr 2>/dev/null | awk '{print $NF}' || echo "0")
    else
        start=$(python3 -c "import time; print(time.time())")
        plasmate fetch "$url" > "$tmpfile" 2>/dev/null || true
        end=$(python3 -c "import time; print(time.time())")
        elapsed=$(echo "$end - $start" | bc)
        mem_kb=0
    fi

    output_size=$(wc -c < "$tmpfile" | tr -d ' ')
    tokens=$(python3 scripts/count-tokens.py < "$tmpfile")
    rm -f "$tmpfile"

    echo "$elapsed $mem_kb $output_size $tokens"
}

# Run comparisons
TOTAL_CHROME_TIME=0
TOTAL_PLASMATE_TIME=0
TOTAL_CHROME_MEM=0
TOTAL_PLASMATE_MEM=0
TOTAL_CHROME_TOKENS=0
TOTAL_PLASMATE_TOKENS=0
TESTED=0

{
echo "Plasmate vs Chrome Headless Comparison"
echo "======================================="
echo "Date: $(date)"
echo "URLs tested: $MAX_URLS"
echo ""
printf "%-50s %10s %10s %10s %10s %10s %10s\n" \
    "URL" "Chrome(s)" "Plasm(s)" "Chr(MB)" "Plasm(MB)" "Chr(tok)" "Plasm(tok)"
echo "---------------------------------------------------------------------------------------------------------------"

for i in $(seq 0 $((MAX_URLS - 1))); do
    url="${URLS[$i]}"
    TESTED=$((TESTED + 1))

    echo -n "  [$TESTED] Testing $url ..." >&2

    read -r c_time c_mem c_size c_tokens <<< "$(measure_chrome "$url")"
    read -r p_time p_mem p_size p_tokens <<< "$(measure_plasmate "$url")"

    c_mem_mb=$(echo "scale=1; $c_mem / 1024" | bc)
    p_mem_mb=$(echo "scale=1; $p_mem / 1024" | bc)

    printf "%-50s %10s %10s %8sMB %8sMB %10s %10s\n" \
        "$url" "${c_time}s" "${p_time}s" "$c_mem_mb" "$p_mem_mb" "$c_tokens" "$p_tokens"

    TOTAL_CHROME_TIME=$(echo "$TOTAL_CHROME_TIME + $c_time" | bc)
    TOTAL_PLASMATE_TIME=$(echo "$TOTAL_PLASMATE_TIME + $p_time" | bc)
    TOTAL_CHROME_MEM=$((TOTAL_CHROME_MEM + c_mem))
    TOTAL_PLASMATE_MEM=$((TOTAL_PLASMATE_MEM + p_mem))
    TOTAL_CHROME_TOKENS=$((TOTAL_CHROME_TOKENS + c_tokens))
    TOTAL_PLASMATE_TOKENS=$((TOTAL_PLASMATE_TOKENS + p_tokens))

    echo " done" >&2
done

echo ""
echo "======================================="
echo "TOTALS ($TESTED URLs)"
echo "======================================="
echo ""
echo "  Time:"
echo "    Chrome:   ${TOTAL_CHROME_TIME}s"
echo "    Plasmate: ${TOTAL_PLASMATE_TIME}s"
if [[ $(echo "$TOTAL_PLASMATE_TIME > 0" | bc) -eq 1 ]]; then
    SPEED_RATIO=$(echo "scale=1; $TOTAL_CHROME_TIME / $TOTAL_PLASMATE_TIME" | bc)
    echo "    Speedup:  ${SPEED_RATIO}x faster"
fi
echo ""
echo "  Memory (avg per page):"
AVG_C_MEM=$(echo "scale=1; $TOTAL_CHROME_MEM / $TESTED / 1024" | bc)
AVG_P_MEM=$(echo "scale=1; $TOTAL_PLASMATE_MEM / $TESTED / 1024" | bc)
echo "    Chrome:   ${AVG_C_MEM}MB"
echo "    Plasmate: ${AVG_P_MEM}MB"
echo ""
echo "  Tokens:"
echo "    Chrome (HTML):   $TOTAL_CHROME_TOKENS"
echo "    Plasmate (SOM):  $TOTAL_PLASMATE_TOKENS"
if [[ "$TOTAL_PLASMATE_TOKENS" -gt 0 ]]; then
    TOKEN_RATIO=$(echo "scale=1; $TOTAL_CHROME_TOKENS / $TOTAL_PLASMATE_TOKENS" | bc)
    echo "    Compression:     ${TOKEN_RATIO}x"
fi
echo ""

} | tee "$RESULTS_FILE"

echo "Results saved to: $RESULTS_FILE"
