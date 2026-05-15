# Data Contributions

This guide covers how to contribute ingredient data in your language.

Each language also has detailed food rules covering naming conventions, qualifier syntax, label definitions, and processing steps. These are especially useful when using LLMs to generate or expand data:

- [Dutch food rules](https://github.com/Rouzax/MealieSync/blob/main/Data/nl/NL_FOOD_RULES.md)
- [French food rules](https://github.com/Rouzax/MealieSync/blob/main/Data/fr/FR_FOOD_RULES.md)
- [English food rules (template)](https://github.com/Rouzax/MealieSync/blob/main/Data/EN_FOOD_RULES.md)

## Available Languages

| Code    | Language       | Status                             |
| ------- | -------------- | ---------------------------------- |
| `nl`    | Dutch          | 1,312 foods, actively maintained   |
| `fr`    | French         | 1,311 foods                        |
| `en`    | English        | Open to contributions              |
| `de`    | German         | Open to contributions              |
| *other* | Your language? | [Start here](#how-to-contribute)   |

## Folder Structure

```
Data/
├── nl/                 # Dutch
│   ├── Foods/          # One file per label/category
│   │   ├── groente.json
│   │   ├── fruit.json
│   │   └── ...
│   ├── Labels.json
│   ├── Units.json
│   ├── Categories.json
│   ├── Tags.json
│   └── Tools.json
│
├── fr/                 # French (same structure)
│   └── ...
│
└── {language-code}/    # Your language
    └── ...
```

Food items share stable UUIDs across language files. When translating, keep the same `id` so that "aardappel" (NL) and "pomme de terre" (FR) are linked.

## How to Contribute

### Option 1: Start from Scratch

1. Create a folder with your [ISO 639-1 language code](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes) (e.g., `de`, `es`)
2. Create JSON files following the [JSON format](../reference/json-format.md)
3. Submit a pull request

### Option 2: Translate Existing Data

1. Export the Dutch data using MealieSync
2. Translate the names, plurals, descriptions, and aliases
3. Keep the same structure and IDs (for cross-language linking)
4. Submit a pull request

### Option 3: Use AI/LLM Assistance

MealieSync's JSON format works well with AI tools:

1. Use an LLM to generate ingredients in your language based on the Dutch data structure
2. Have the AI create descriptions, plurals, and aliases
3. Review and correct the output
4. Validate with MealieSync's `-WhatIf` mode before importing
5. Submit a pull request

This is a fast way to bootstrap a new language or expand an existing dataset with cuisine-specific ingredients.

## Data Quality Guidelines

### What Makes a Good Ingredient?

**Include:**

- Raw ingredients (vegetables, fruits, meats, herbs)
- Semi-prepared products used as ingredients (flour, pasta, bouillon)
- Sauces and condiments added to dishes
- Pre-prepared items purchased ready-to-use (smoked fish, deli meats)

**Do not include:**

- Dishes or recipes (mashed potatoes, croissants, smoothies)
- Ready-to-eat meals (frozen pizza, pre-made salads)
- Brand names (use generic terms)
- Terms that are too generic ("juice", "dough")
- Obscure items unknown to most people

### Naming Rules

1. **Use the common name in your language**
2. **Always singular.** Plural goes in `pluralName`
3. **No brand names.** Use generic terms
4. **Native language first.** English only if internationally adopted

| Wrong           | Correct              |
| --------------- | -------------------- |
| maple syrup     | ahornsiroop (Dutch)  |
| Heinz ketchup   | ketchup              |
| potatoes        | potato               |

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

**Rule of thumb:** if in doubt, create a separate ingredient.

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

**Label by what it is, not where it comes from:**

| Ingredient   | Wrong   | Correct              |
| ------------ | ------- | -------------------- |
| oyster sauce | Seafood | Sauces & Condiments  |
| fish stock   | Seafood | Stocks & Broths      |
| mozzarella   | Dairy   | Cheese               |
| honey        | Baking  | Sweets               |
| tofu         | Dairy   | Legumes              |

### Descriptions

Format: `[Brief definition]; [typical use or characteristics].`

Examples:

- "Dark sauce from oyster extract; savory flavor enhancer in Asian cuisine."
- "Fatty fish; pink flesh, versatile preparation."
- "Spice blend for Cajun dishes; spicy with paprika and cayenne."

Keep descriptions concise and informative.

## Checklist Before Submitting

- [ ] Items are ingredients (not dishes or recipes)
- [ ] Primary name is in the target language
- [ ] Names are singular (plural in `pluralName`)
- [ ] Aliases are true synonyms (not varieties or derivatives)
- [ ] Correct labels assigned
- [ ] No duplicates (check aliases too)
- [ ] No brand names
- [ ] Fresh/dried and whole/ground are properly split
- [ ] JSON files use the [wrapper format](../reference/json-format.md)
