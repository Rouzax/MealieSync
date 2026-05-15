# Using LLMs to Curate Data

MealieSync includes an LLM prompt kit that lets you use AI assistants (Claude, ChatGPT, etc.) to generate, improve, and expand ingredient data. The prompt enforces all the naming, aliasing, and labeling rules automatically.

## What's in the Kit

The Dutch prompt kit lives in [`Data/nl/llm-prompt/`](https://github.com/Rouzax/MealieSync/tree/main/Data/nl/llm-prompt):

| File | Purpose |
|---|---|
| `system-prompt.txt` | System prompt that sets the LLM's role and output format |
| `CONTRACT_v4.md` | The normative specification: all rules the LLM must follow |
| `Qualifiers_v2.json` | Machine-readable whitelist of allowed bracket qualifiers with alias generation patterns |

The contract references `Labels.json` from the parent data folder (`Data/nl/Labels.json`) as the canonical label list.

## How to Use It

1. Start a new conversation with your preferred LLM
2. Set `system-prompt.txt` as the system message (or paste it as the first message)
3. Attach all three files plus `Data/nl/Labels.json` as context
4. Provide your input (see below)
5. Review the LLM's output: a complete JSON wrapper plus a change report
6. Validate with MealieSync before importing:

```powershell
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\output.json -UpdateExisting -WhatIf
```

## Input Formats

You can give the LLM input in three ways:

**A JSON file to improve.** Hand the LLM one of the existing category files (e.g., `Data/nl/Foods/groente.json`) and ask it to review, fix, or expand it.

**A list of ingredient names.** Just paste raw names, one per line. The LLM creates full entries with plurals, descriptions, aliases, and labels.

**A category to expand.** Ask the LLM to suggest missing ingredients for a label (e.g., "What common Dutch vegetables are missing from this list?").

## What the LLM Does

Following the contract, the LLM:

- Normalizes names, plurals, and aliases (trimming, deduplication, case handling)
- Validates bracket qualifiers against the whitelist (e.g., `[vers]`, `[gemalen]`, `[blik]`)
- Splits items that need separate entries (fresh vs dried, whole vs ground, juice vs zest vs peel)
- Merges safe duplicates (exact name match or unique alias overlap)
- Assigns labels from the fixed list
- Generates descriptions in the required format (`definition; usage.`, max 100 characters)
- Expands aliases based on qualifier patterns (e.g., `citroen [sap]` gets alias `citroensap`)
- Reports all changes with at least 5 concrete examples

## The Qualifier System

`Qualifiers_v2.json` defines the allowed bracket qualifiers with metadata:

```json
{
  "name": "vers",
  "category": "toestand",
  "alias_patterns": ["{base} vers", "verse {base}", "vers {base}"],
  "split_group": "toestand",
  "disallowed_labels": ["Groente", "Fruit"]
}
```

Each qualifier has:

- **`alias_patterns`**: templates for auto-generating aliases (e.g., `citroen [sap]` gets alias `citroensap`)
- **`split_group`**: qualifiers in the same group trigger mandatory splits (fresh vs dried, whole vs ground)
- **`disallowed_labels`**: labels where this qualifier must not appear (e.g., vegetables are always fresh by default, so `[vers]` is never used)

## Tips

- Always review LLM output before importing. The prompt is thorough but not infallible.
- Use `-WhatIf` to preview what the import would do.
- Run conflict detection on the output before importing into a folder with other files.
- For large batches, process one category file at a time.
- The LLM's change report includes item counts and first/last item names as a quick sanity check.

## Creating a Kit for Another Language

To create a prompt kit for a new language:

1. Copy the Dutch kit as a starting point
2. Translate the contract to the target language
3. Create a language-specific `Qualifiers.json` with translated qualifier names and alias patterns
4. Use the target language's `Labels.json`
5. Adjust naming rules for the language's grammar (e.g., French uses parentheses instead of square brackets, and qualifiers must agree in gender)
