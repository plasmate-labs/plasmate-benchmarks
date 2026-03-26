# Plasmate Benchmarks

Reproducible benchmarks for [Plasmate](https://plasmate.app) - the browser engine for AI agents.

Run these yourself. Verify our claims. No trust required.

## Quick Start

```bash
# Install Plasmate
pip install plasmate
# or: cargo install plasmate
# or: npm install -g plasmate

# Clone this repo
git clone https://github.com/plasmate-labs/plasmate-benchmarks
cd plasmate-benchmarks

# Run the full benchmark
./run-benchmark.sh
```

## What We Claim

| Metric | Claim | How to Verify |
|--------|-------|---------------|
| Token compression | 16.6x fewer tokens vs raw HTML | `./run-benchmark.sh` |
| Cost savings | ~94% reduction at GPT-4 rates | `./run-cost-analysis.sh` |
| Speed | 50x faster than Chrome headless | `./compare-chrome.sh` |
| Memory | ~30MB vs Chrome's 300-500MB | `./compare-chrome.sh` |

## Benchmark URLs

We test against 49 real-world websites spanning:
- News sites (CNN, BBC, Reuters, TechCrunch)
- E-commerce (Amazon, eBay, Etsy)
- Documentation (MDN, Python docs, Rust docs)
- Social platforms (Reddit, HN, GitHub)
- SaaS dashboards (Stripe, Vercel, Netlify)
- Government sites (USA.gov, NHS)
- Wikipedia, Stack Overflow, and more

See `urls.txt` for the full list.

## run-benchmark.sh

Runs Plasmate against all 49 URLs and compares SOM token count vs raw HTML token count.

Output:
- Per-URL token counts (HTML vs SOM)
- Compression ratios
- Aggregate statistics (mean, median, total)
- Results saved to `results/benchmark-YYYY-MM-DD.json`

## run-cost-analysis.sh

Calculates the dollar cost of processing these pages with different LLMs:
- GPT-4 ($30/1M input tokens)
- GPT-4o ($2.50/1M input tokens)
- Claude 3.5 Sonnet ($3/1M input tokens)

Shows the cost difference between Chrome (raw HTML tokens) and Plasmate (SOM tokens) at scale (1K, 10K, 100K, 1M pages/month).

## compare-chrome.sh

Requires Chrome/Chromium installed. Runs the same URLs through both:
1. Chrome headless (dumps full DOM)
2. Plasmate (outputs SOM)

Measures and compares:
- Wall clock time
- Peak memory usage
- Output size (bytes)
- Token count

## Methodology

- Token counting uses `tiktoken` with the `cl100k_base` encoding (GPT-4 tokenizer)
- Each URL is fetched fresh (no caching)
- Chrome uses `--headless=new --dump-dom`
- Plasmate uses `plasmate fetch <url>` (outputs SOM JSON to stdout)
- Memory measured via `/usr/bin/time -v` (Linux) or `command time -l` (macOS)

## Contributing

Found a URL that breaks Plasmate? Open an issue with the URL and we'll investigate.

Want to add URLs to the benchmark? PRs welcome - just add to `urls.txt`.

## License

Apache 2.0 - same as Plasmate itself.


---

## Part of the Plasmate Ecosystem

| | |
|---|---|
| **Engine** | [plasmate](https://github.com/plasmate-labs/plasmate) - The browser engine for agents |
| **MCP** | [plasmate-mcp](https://github.com/plasmate-labs/plasmate-mcp) - Claude Code, Cursor, Windsurf |
| **Extension** | [plasmate-extension](https://github.com/plasmate-labs/plasmate-extension) - Chrome cookie export |
| **SDKs** | [Python](https://github.com/plasmate-labs/plasmate-python) / [Node.js](https://github.com/plasmate-labs/quickstart-node) / [Go](https://docs.plasmate.app/sdk-go) / [Rust](https://github.com/plasmate-labs/quickstart-rust) |
| **Frameworks** | [LangChain](https://github.com/langchain-ai/langchain/pull/36208) / [CrewAI](https://github.com/plasmate-labs/crewai-plasmate) / [AutoGen](https://github.com/plasmate-labs/autogen-plasmate) / [Smolagents](https://github.com/plasmate-labs/smolagents-plasmate) |
| **Tools** | [Scrapy](https://github.com/plasmate-labs/scrapy-plasmate) / [Audit](https://github.com/plasmate-labs/plasmate-audit) / [A11y](https://github.com/plasmate-labs/plasmate-a11y) / [GitHub Action](https://github.com/plasmate-labs/som-action) |
| **Resources** | [Awesome Plasmate](https://github.com/plasmate-labs/awesome-plasmate) / [Notebooks](https://github.com/plasmate-labs/notebooks) / [Benchmarks](https://github.com/plasmate-labs/plasmate-benchmarks) |
| **Docs** | [docs.plasmate.app](https://docs.plasmate.app) |
| **W3C** | [Web Content Browser for AI Agents](https://www.w3.org/community/web-content-browser-ai/) |
