#!/usr/bin/env python3
"""Pretty-print benchmark results from a JSON file."""
import json
import sys
import statistics


def format_results(filepath: str) -> None:
    with open(filepath) as f:
        results = json.load(f)

    if not results:
        print("No results found.")
        return

    print(f"\n{'='*80}")
    print(f"  Benchmark Results: {filepath}")
    print(f"{'='*80}\n")

    ratios = []
    html_total = 0
    som_total = 0

    print(f"{'#':<4} {'Ratio':<8} {'HTML Tokens':<14} {'SOM Tokens':<14} {'URL'}")
    print(f"{'-'*4} {'-'*8} {'-'*14} {'-'*14} {'-'*40}")

    for i, r in enumerate(results, 1):
        url = r.get("url", "N/A")
        html_tokens = r.get("html_tokens", 0)
        som_tokens = r.get("som_tokens", 0)
        ratio = r.get("ratio", 0)

        html_total += html_tokens
        som_total += som_tokens
        if isinstance(ratio, (int, float)) and ratio > 0:
            ratios.append(ratio)

        print(f"{i:<4} {ratio:<8} {html_tokens:<14,} {som_tokens:<14,} {url}")

    print(f"\n{'='*80}")
    print(f"  Summary")
    print(f"{'='*80}\n")

    print(f"  Pages tested:        {len(results)}")
    print(f"  Total HTML tokens:   {html_total:,}")
    print(f"  Total SOM tokens:    {som_total:,}")

    if som_total > 0:
        overall = html_total / som_total
        print(f"  Overall compression: {overall:.1f}x")

    if ratios:
        print(f"\n  Per-page ratio stats:")
        print(f"    Mean:   {statistics.mean(ratios):.1f}x")
        print(f"    Median: {statistics.median(ratios):.1f}x")
        print(f"    Min:    {min(ratios):.1f}x")
        print(f"    Max:    {max(ratios):.1f}x")
        if len(ratios) > 1:
            print(f"    Stdev:  {statistics.stdev(ratios):.1f}")

    print()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <results-file.json>")
        sys.exit(1)
    format_results(sys.argv[1])
