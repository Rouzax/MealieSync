# Contributing Data to MealieSync

This folder contains ingredient and recipe metadata organized by language. Community contributions for new languages are welcome!

## Available Languages

| Code    | Language       | Status                             | Contents                                      |
| ------- | -------------- | ---------------------------------- | --------------------------------------------- |
| `nl`    | Dutch          | ✅ Complete                         | Foods, Units, Labels, Categories, Tags, Tools |
| `en`    | English        | 💬 Open to contributions            | —                                             |
| `de`    | German         | 💬 Open to contributions            | —                                             |
| `fr`    | French         | 💬 Open to contributions            | —                                             |
| *other* | Your language? | 💬 [Start here](#how-to-contribute) | —                                             |

## Folder Structure

```
Data/
├── README.md           # This file
├── nl/                 # Dutch
│   ├── Foods/          # Split by label (one file per category)
│   │   ├── groente.json
│   │   ├── fruit.json
│   │   └── ...
│   ├── Labels.json
│   ├── Units.json
│   ├── Categories.json
│   ├── Tags.json
│   └── Tools.json
│
└── {language-code}/    # Your language
    └── ...
```

---

## How to Contribute

### Option 1: Start from Scratch

1. Create a folder with your [ISO 639-1 language code](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes) (e.g., `de`, `fr`, `es`)
2. Create JSON files following the format in [JSON Format](#json-format)
3. Submit a pull request

### Option 2: Translate Existing Data

1. Export the Dutch data using MealieSync
2. Translate the names, plurals, descriptions, and aliases
3. Keep the same structure and IDs (for consistency)
4. Submit a pull request

### Option 3: Use AI/LLM Assistance

MealieSync's JSON format works great with AI tools:

1. Use an LLM to generate ingredients in your language based on the Dutch data structure
2. Have the AI create descriptions, plurals, and aliases
3. Review and correct the output
4. Validate with MealieSync's `-WhatIf` mode before importing
5. Submit a pull request

This is a fast way to bootstrap a new language or expand an existing database with cuisine-specific ingredients.

---

## JSON Format

All files must use the MealieSync wrapper format:

```json
{
  "$schema": "mealie-sync",
  "$type": "Foods",
  "$version": "1.0",
  "items": [
    { ... }
  ]
}
```

### Food Entry

```json
{
  "id": "b9dc4c47-c569-4630-846f-1f4b4fbda3c1",
  "name": "tomato",
  "pluralName": "tomatoes",
  "description": "Red fruit; versatile in salads, sauces, and dishes.",
  "aliases": [
    { "name": "cherry tomato" },
    { "name": "roma tomato" }
  ],
  "label": "Vegetables",
  "householdsWithIngredientFood": ["household-name"]
}
```

| Field                          | Required | Description                                               |
| ------------------------------ | :------: | --------------------------------------------------------- |
| `id`                           |    —     | UUID (auto-generated if missing, keep stable for updates) |
| `name`                         |    ✅     | Primary name (singular)                                   |
| `pluralName`                   |    —     | Plural form                                               |
| `description`                  |    —     | Short description                                         |
| `aliases`                      |    —     | Alternative names (array of objects)                      |
| `label`                        |    —     | Category label name                                       |
| `householdsWithIngredientFood` |    —     | Households that have this ingredient                      |

---

## Data Quality Guidelines

### What Makes a Good Ingredient?

**Include:**
- Raw ingredients (vegetables, fruits, meats, herbs)
- Semi-prepared products used as ingredients (flour, pasta, bouillon)
- Sauces and condiments added to dishes
- Pre-prepared items purchased ready-to-use (smoked fish, deli meats)

**Don't include:**
- Dishes or recipes (mashed potatoes, croissants, smoothies)
- Ready-to-eat meals (frozen pizza, pre-made salads)
- Brand names (use generic terms)
- Terms that are too generic ("juice", "dough")
- Obscure items unknown to most people

### Naming Rules

1. **Use the common name in your language**
2. **Always singular** — plural goes in `pluralName`
3. **No brand names** — use generic terms
4. **Native language first** — English only if internationally adopted

| ❌ Wrong       | ✅ Correct           |
| ------------- | ------------------- |
| maple syrup   | ahornsiroop (Dutch) |
| Heinz ketchup | ketchup             |
| potatoes      | potato              |

### Aliases

Aliases are **alternative names for the exact same ingredient**.

**Good aliases:**
- Synonyms: "spud" for potato
- Translations: "maizena" for cornstarch
- Spelling variants: "jalapeno" for jalapeño
- Spaced variants: "soy sauce" for soysauce

**Not aliases (create separate entries instead):**
- Varieties: "Granny Smith" is not an alias for "apple"
- Derived products: "lemon juice" is not an alias for "lemon"
- Different products: "bok choy" is not an alias for "cabbage"
- Preparations: "espresso" is not an alias for "coffee"

**Rule of thumb:** If in doubt, create a separate ingredient.

### When to Split Ingredients

Always create **separate entries** for:

| Situation             | Example                            |
| --------------------- | ---------------------------------- |
| Different plant parts | cilantro (leaf) vs coriander seed  |
| Fresh vs dried        | ginger vs ginger powder            |
| Whole vs ground       | nutmeg vs ground nutmeg            |
| Zest/juice/peel       | lemon vs lemon zest vs lemon juice |
| Different cuts        | chicken breast vs chicken thigh    |

### Label Assignment

**Label by what it IS, not where it comes from:**

| Ingredient   | ❌ Wrong | ✅ Correct           |
| ------------ | ------- | ------------------- |
| oyster sauce | Seafood | Sauces & Condiments |
| fish stock   | Seafood | Stocks & Broths     |
| mozzarella   | Dairy   | Cheese              |
| honey        | Baking  | Sweets              |
| tofu         | Dairy   | Legumes             |

### Descriptions

Format: `[Brief definition]; [typical use or characteristics].`

Examples:
- "Dark sauce from oyster extract; savory flavor enhancer in Asian cuisine."
- "Fatty fish; pink flesh, versatile preparation."
- "Spice blend for Cajun dishes; spicy with paprika and cayenne."

Keep descriptions concise and informative.

---

## Checklist Before Submitting

Before adding an ingredient, verify:

- [ ] It's an ingredient (not a dish or recipe)
- [ ] Primary name is in the target language
- [ ] Name is singular (plural in `pluralName`)
- [ ] Aliases are true synonyms (not varieties or derivatives)
- [ ] Correct label assigned
- [ ] Doesn't already exist (check aliases too)
- [ ] Not a brand name
- [ ] Fresh/dried and whole/ground are properly split

---

## Questions?

Open an issue on GitHub or start a discussion. We're happy to help!