#!/usr/bin/env python3
"""Count tokens from stdin using tiktoken (GPT-4 tokenizer)."""
import sys
import tiktoken

enc = tiktoken.get_encoding("cl100k_base")
text = sys.stdin.read()
print(len(enc.encode(text)))
