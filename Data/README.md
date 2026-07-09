# Contributing Data to MealieSync

This folder contains ingredient and recipe metadata organized by language. Community contributions for new languages are welcome!

For the full data contribution guide, including quality guidelines, naming rules, alias conventions, and a submission checklist, see the **[documentation site](https://rouzax.github.io/MealieSync/contributing/data-guide/)**.

## Available Languages

| Code    | Language       | Status                             | Contents                                      |
| ------- | -------------- | ---------------------------------- | --------------------------------------------- |
| `nl`    | Dutch          | 1,316 foods, actively maintained   | Foods, Units, Labels, Categories, Tags, Tools |
| `fr`    | French         | 1,316 foods, mirrors `nl` by UUID  | Foods, Units, Labels, Categories, Tags, Tools |
| `en`    | English        | Open to contributions              |                                               |
| `de`    | German         | Open to contributions              |                                               |
| *other* | Your language? | [Start here](#how-to-contribute)   |                                               |

## Folder Structure

```
Data/
├── EN_FOOD_RULES.md    # English food rules (template for new languages)
├── nl/                 # Dutch
│   ├── NL_FOOD_RULES.md
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
├── fr/                 # French
│   ├── FR_FOOD_RULES.md
│   ├── Foods/
│   │   ├── Légumes.json
│   │   ├── Fruits.json
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

Food items share stable UUIDs across language files. When translating, keep the same `id` so that "aardappel" (NL) and "pomme de terre" (FR) are linked.

## Food Rules

Each language has a detailed food rules file covering naming conventions, qualifier syntax, label definitions, and processing steps. These are especially useful when using LLMs to generate or expand data:

- [Dutch food rules](nl/NL_FOOD_RULES.md)
- [French food rules](fr/FR_FOOD_RULES.md)
- [English food rules (template)](EN_FOOD_RULES.md)

## How to Contribute

1. Create a folder with your [ISO 639-1 language code](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes) (e.g., `de`, `es`)
2. Copy the English food rules as a starting template
3. Create JSON files following the [JSON format](https://rouzax.github.io/MealieSync/reference/json-format/)
4. Validate with MealieSync's `-WhatIf` mode before importing
5. Submit a pull request

You can translate existing data (export the Dutch set, translate, keep the same IDs) or use an LLM to bootstrap a new language. See the [full guide](https://rouzax.github.io/MealieSync/contributing/data-guide/) for details.

## Questions?

[Open an issue](https://github.com/Rouzax/MealieSync/issues) on GitHub. We're happy to help!
