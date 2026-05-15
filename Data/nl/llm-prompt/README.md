# LLM Prompt Kit for Dutch Ingredient Data

This folder contains files for using an LLM to curate and expand the Dutch ingredient database.

## Files

| File | Purpose |
|---|---|
| `system-prompt.txt` | System prompt for the LLM (set as system message or paste first) |
| `CONTRACT_v4.md` | Normative specification, the "source of truth" the LLM must follow |
| `Qualifiers_v2.json` | Machine-readable whitelist of allowed bracket qualifiers with alias patterns |

The Labels list is not duplicated here. Use `Data/nl/Labels.json` as the canonical label set.

## How to Use

1. Start a new LLM conversation (Claude, ChatGPT, etc.)
2. Set `system-prompt.txt` as the system message (or paste it as the first message)
3. Attach `CONTRACT_v4.md` and `Qualifiers_v2.json` as context
4. Also attach `Data/nl/Labels.json` as the valid label list
5. Provide your input: a JSON file to improve, a list of ingredient names, or a category to expand

The LLM will output a complete MealieSync-compatible JSON wrapper plus a change report.

## Input Formats

The prompt supports three input formats:
- **JSON wrapper** with `items` array (standard MealieSync format)
- **JSON array** of ingredient objects
- **Plain text list** of ingredient names (the LLM creates full entries)

## What the LLM Does

Following the contract, the LLM will:
- Normalize names, plurals, and aliases
- Fix bracket qualifiers to match the whitelist
- Split items that need separate entries (fresh/dried, whole/ground, etc.)
- Deduplicate and merge safely
- Assign correct labels
- Generate descriptions in the standard format
- Expand aliases based on qualifier patterns
- Report all changes with concrete examples

Always review the output and validate with `Invoke-MealieSync.ps1 -WhatIf` before importing.
