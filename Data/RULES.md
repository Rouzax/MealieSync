# Mealie Ingredient Database — RULES.md (EN)

## Goal
Build an ingredient database that is **consistent, predictable, and parsing-friendly**:
- unambiguous ingredient names (English)
- clear split rules (fresh/dried, whole/ground, juice/zest/peel, etc.)
- aliases only for true synonyms/spelling variants
- labels always from a fixed list (your Mealie label set)

---

## Mealie terminology

| Term       | Applies to  | Example                  |
| ---------- | ----------- | ------------------------ |
| **Labels** | Ingredients | Vegetables, Meat, Cheese |
| **Tags**   | Recipes     | Vegetarian, Quick        |

This document covers **Labels** and how to model **ingredients**.

---

## JSON conventions (import-ready)
An ingredient object includes at minimum:
- `name` (string) — canonical name (English)
- `pluralName` (string) — common plural (or equal to `name` for mass nouns / fixed plurals)
- `description` (string) — short: `definition; use/prep.`
- `aliases` (array) — always present, at least `[]`, items as `{ "name": "..." }`
- `label` (string) — exactly one label from your Mealie instance

**Normalization**
- trim spaces in `name`, `pluralName`, and alias names; no double spaces
- dedupe aliases **case-insensitive**
- no alias identical to `name` or `pluralName` (case-insensitive)
- prefer **lowercase** for ingredient names (unless capitalization is truly standard)

---

## 1. What counts as an ingredient?

### Include
- Basic foods (vegetables, fruit, meat, herbs, etc.)
- Pantry staples used as ingredients (flour, pasta, stock, sauces)
- Condiments/flavorings (soy sauce, mustard, chili paste)
- Store-bought prepped ingredients used as a base:
  - smoked mackerel, chicken schnitzel, shawarma strips, roasted almonds

### Exclude
- Preparations/dishes you typically make yourself:
  - mashed potatoes, overnight oats, soufflé, batter, homemade pesto
- Ready-made dishes as “a dish”:
  - parfait, sorbet, petit fours
- Brand names
- Overly generic terms without product context:
  - “juice”, “dough”
- Obscure/rare items (add conservatively)

---

## 2. Naming

### 2.1 Primary name (`name`)
- Use the **common English name**
- Use the **most common native form**:
  - usually singular
  - allow fixed plural product names where that is standard (e.g., oats, breadcrumbs)
- No brand names
- Avoid foreign-language names unless they are the standard English product name

### 2.2 Form / state qualifiers (parentheses)
For forms/states that would otherwise be ambiguous, use a consistent notation:
- variants are unambiguous
- parsing is simple
- names stay recognizable for cooks

**Main rule**
`base name (qualifier)`

Use this for clear splits:
- State: `(fresh)`, `(dried)`
- Grind: `(whole)`, `(ground)`
- Shape: `(flakes)`, `(sticks)`
- Citrus forms: `(juice)`, `(zest)`, `(peel)`
- Pepper form: `(peppercorns)` when useful

**Exception: powders as product names**
If “X powder” is the common and recognizable product name, use it as `name`
(instead of `x (ground)`), e.g.:
- garlic powder
- onion powder
- ginger powder
- cinnamon powder
- paprika powder
- chili powder

Keep alternative spellings as aliases (see Aliases).

**When NOT to use parentheses**
- If English has a fixed product term that is not a form/state qualifier:
  - chicken breast, chicken thigh, egg yolk, egg white, cottage cheese

### 2.3 Plural (`pluralName`)
- Use the **common plural**
- For mass nouns or fixed plurals (e.g., rice, salt, oats, breadcrumbs): `pluralName == name` is allowed
- For parenthesized variants:
  - often treated as mass nouns → `pluralName == name` (e.g., cilantro (fresh))
  - if the qualifier indicates a countable form, pluralize where sensible:
    - black pepper (peppercorn) → black pepper (peppercorns)
    - cinnamon (stick) → cinnamon (sticks)

### Naming examples (non-English → English)
| ❌ Wrong (not English)     | ✅ Correct (English)      |
| ------------------------- | ------------------------ |
| ahornsiroop               | maple syrup              |
| sirop de Liège            | Liège syrup              |
| edelgistvlokken           | nutritional yeast flakes |
| mineraalwater (as a name) | mineral water            |
| hüttenkäse                | cottage cheese           |
| bakbanaan                 | plantain                 |

---

## 3. Aliases (`aliases`)

### 3.1 What is an alias?
An alias is an **alternative name for the exact same ingredient**:
- synonym, translation, spelling variant, diacritics/no diacritics, spacing/hyphen variants

### 3.2 Aliases and plurals
The plural belongs in `pluralName`, not as an alias.

Aliases may include both singular and plural only if common usage includes both.

Example:
```json
{
  "name": "potato",
  "pluralName": "potatoes",
  "aliases": [
    { "name": "spud" },
    { "name": "spuds" }
  ]
}
```

### 3.3 Never as alias (always separate items)

* Varieties/cultivars: Granny Smith, Gala, etc.
* Different derived products/forms: lemon (juice) ≠ lemon; lime (zest) ≠ lime
* Different products: currants ≠ raisins
* Preparations: espresso ≠ coffee; pulled pork ≠ pork shoulder
* Truly different products: buffalo mozzarella ≠ mozzarella

### 3.4 Good alias examples

* Synonyms: scallion ↔ green onion
* Spacing/hyphen variants: stock cube / stock-cube / stockcube

**Powder variants**

* If `name` is “X powder”, add common variants as aliases:

  * garlic powder → garlic-powder, garlic powder (if spacing/hyphen differs)
* If `name` is parenthesized, “X powder” may be an alias only if common:

  * cinnamon (ground) → alias: cinnamon powder (only if common and you did not choose cinnamon powder as `name`)

**Compound forms modeled with parentheses may be aliases**

* lemon juice → lemon (juice)
* lemon zest → lemon (zest)
* black peppercorns → black pepper (peppercorns)

**Rule of thumb:** when in doubt, create a separate ingredient.

---

## 4. Deduplication & consolidation (hard rule)

Merge when:

* `name` matches (case-insensitive), or
* aliases overlap (case-insensitive)

When merging:

* keep one canonical `name` following these rules
* keep the best (shortest/clearest) `description`
* merge + clean aliases
* fix `pluralName`
* fix `label`

---

## 5. Splitting ingredients (hard rule)

### 5.1 Always split when

* Different parts of the same plant/animal (e.g., egg white vs egg yolk)
* fresh vs dried
* whole vs ground
* juice/zest/peel
* clearly different shapes (peppercorns/flakes/sticks)

### 5.2 Naming convention for splits

Use suffix in parentheses:

* x (fresh), x (dried)
* x (whole), x (ground)
* x (juice), x (zest), x (peel)
* x (peppercorns), x (flakes), x (sticks)

Use “X powder” as `name` when that is the common product term (see 2.2).

Move aliases to the correct split item. Remove the old ambiguous entry.

### 5.3 Examples

**Herbs & spices**

* cilantro (fresh) ↔ cilantro (dried) (only if you model both)
* coriander seed (whole) ↔ coriander seed (ground)
* ginger (fresh) ↔ ginger powder
* garlic (fresh) ↔ garlic powder
* onion (fresh) ↔ onion powder
* cinnamon (sticks) ↔ cinnamon powder
* nutmeg (whole) ↔ nutmeg (ground)
* black pepper (peppercorns) ↔ black pepper (ground) (alias: black peppercorns)
* white pepper (peppercorns) ↔ white pepper (ground)

**Citrus**

* lemon ↔ lemon (zest) ↔ lemon (juice)
* lime ↔ lime (zest) ↔ lime (juice)
* orange ↔ orange (zest) ↔ orange (juice)

**Eggs**

* egg, egg yolk, egg white (always separate)

**Cheese**

* mozzarella and buffalo mozzarella are separate
* cheeses by age/type are separate items (no aliases)

---

## 6. Labels

### 6.1 Label principles

1. Label what it **IS**, not origin/use

   * fish stock → **Stock & flavorings** (not Fish & seafood)
   * oyster sauce → **Sauces & condiments** (not Fish & seafood)

2. Cheese is separate from dairy

   * mozzarella, parmesan → **Cheese**
   * milk, yogurt, cream, coconut milk → **Dairy**

3. Sweets = sweet products including spreads

   * jam, honey, syrup, chocolate spread, peanut butter → **Sweets**

4. Deli meats = processed meat

   * ham, bacon, salami, pâté → **Deli meats**

### 6.2 Common mistakes

| Ingredient        | ❌ Wrong label       | ✅ Correct label       |
| ----------------- | ------------------- | --------------------- |
| oyster sauce      | Fish & seafood      | Sauces & condiments   |
| fish stock        | Fish & seafood      | Stock & flavorings    |
| mozzarella        | Dairy               | Cheese                |
| cappuccino powder | Dairy               | Coffee & tea          |
| oats              | Nuts & seeds        | Breakfast cereals     |
| buckwheat         | Baking              | Pasta, rice & noodles |
| raisins           | Sweets              | Fruit                 |
| tofu              | Dairy               | Legumes               |
| peanut butter     | Nuts & seeds        | Sweets                |
| tzatziki          | Dairy               | Sauces & condiments   |
| hummus            | Legumes             | Sauces & condiments   |
| jam               | Sauces & condiments | Sweets                |
| honey             | Baking              | Sweets                |

### 6.3 Label set (example: 29 labels)

**Important:** the `label` string must match your Mealie instance *exactly*. Use this as a reference structure.

#### 🥬 FRESH

| #   | Label             | Description              | Examples                        |
| --- | ----------------- | ------------------------ | ------------------------------- |
| 1   | Vegetables        | Fresh vegetables         | tomato, onion, carrot, jalapeño |
| 2   | Fruit             | Fresh & dried fruit      | apple, banana, raisins          |
| 3   | Fresh herbs       | Fresh herbs (not dried)  | basil, parsley, lemongrass      |
| 4   | Potatoes & tubers | Tubers and similar crops | potato, celeriac, radish        |

#### 🥩 MEAT & FISH

| #   | Label          | Description               | Examples                            |
| --- | -------------- | ------------------------- | ----------------------------------- |
| 5   | Meat           | Raw meat (beef/pork/lamb) | steak, ground beef, pork tenderloin |
| 6   | Poultry        | Raw poultry               | chicken, turkey, duck               |
| 7   | Fish & seafood | Fish and seafood          | salmon, shrimp, mussels, nori       |
| 8   | Deli meats     | Processed meats           | ham, bacon, salami, pâté            |

#### 🧊 CHILLED

| #   | Label  | Description                 | Examples                                  |
| --- | ------ | --------------------------- | ----------------------------------------- |
| 9   | Dairy  | Dairy products (not cheese) | milk, yogurt, cream, coconut milk         |
| 10  | Cheese | All cheeses                 | gouda, mozzarella, parmesan, cream cheese |
| 11  | Eggs   | Eggs and egg parts          | egg, egg yolk, egg white                  |

#### 🍞 BREAD & BREAKFAST

| #   | Label             | Description              | Examples                           |
| --- | ----------------- | ------------------------ | ---------------------------------- |
| 12  | Bread & pastries  | Bread and pastries       | bread, croissant, tortilla         |
| 13  | Baking            | Baking ingredients       | flour, sugar, baking powder, yeast |
| 14  | Breakfast cereals | Breakfast grains/cereals | oats, muesli, granola              |

#### 📦 DRY GOODS

| #   | Label                 | Description        | Examples                     |
| --- | --------------------- | ------------------ | ---------------------------- |
| 15  | Pasta, rice & noodles | Dry carbs          | spaghetti, rice, ramen, udon |
| 16  | Legumes               | Beans/lentils/peas | chickpeas, lentils, tofu     |
| 17  | Nuts & seeds          | Nuts and seeds     | almonds, walnuts, sesame     |

#### 🧂 SPICES & SAUCES

| #   | Label               | Description                 | Examples                            |
| --- | ------------------- | --------------------------- | ----------------------------------- |
| 18  | Herbs & spices      | Dried herbs and spices      | cumin, cinnamon powder, galangal    |
| 19  | Oil, vinegar & fat  | Oils, vinegars, fats        | olive oil, butter, balsamic vinegar |
| 20  | Sauces & condiments | Sauces and condiments       | ketchup, soy sauce, sambal, pesto   |
| 21  | Stock & flavorings  | Stock, bouillon, flavorings | stock cube, fond, msg               |

#### 🍫 SNACKS & SWEET

| #   | Label  | Description                  | Examples                                    |
| --- | ------ | ---------------------------- | ------------------------------------------- |
| 22  | Snacks | Savory snacks                | chips, popcorn, crackers                    |
| 23  | Sweets | Sweet products incl. spreads | chocolate, candy, jam, honey, peanut butter |

#### 🥤 DRINKS

| #   | Label              | Description               | Examples                   |
| --- | ------------------ | ------------------------- | -------------------------- |
| 24  | Drinks             | Soft drinks, juice, water | cola, orange juice, tonic  |
| 25  | Wine               | Wine incl. fortified      | red wine, sherry, port     |
| 26  | Beer               | All beers                 | lager, wheat beer, IPA     |
| 27  | Spirits & liqueurs | Distilled/liqueurs        | rum, whisky, cointreau     |
| 28  | Coffee & tea       | Hot drinks                | coffee, green tea, rooibos |

#### 📍 OTHER

| #   | Label | Description      | Examples |
| --- | ----- | ---------------- | -------- |
| 29  | Other | Not classifiable | misc.    |

---

## 7. Descriptions (`description`)

### Fixed format

`[Short definition]; [use/prep].`

### Guidelines

* short and factual, no marketing
* guideline: < ~80 characters (conservative)
* mention 1 key characteristic + 1 typical use

### Examples

* Dark sauce made from oyster extract; savory seasoning in Asian cooking.
* Fatty fish; versatile to cook.
* Cajun spice blend; spicy with paprika and cayenne.

---

## 8. Processing steps (always)

1. Validate & normalize

   * `aliases` always present (at least `[]`)
   * trim & dedupe aliases (case-insensitive)
2. Deduplicate & consolidate

   * merge on `name` and alias overlap
3. Split where needed

   * replace mixed/ambiguous items with clear split items
4. Improve

   * fix pluralName, label, description format
5. Expand (conservatively, within scope)

   * only common ingredients that match the category
6. Sort

   * alphabetical by `name` for stable diffs

---

## 9. Checklist

* [ ] Is it an ingredient (not a preparation/dish)?
* [ ] Is `name` common English (usually singular; fixed plurals allowed)?
* [ ] Is the form/state unambiguous (split if needed)?
* [ ] Are powders named as “X powder” where that is the common product term?
* [ ] Are aliases true synonyms/spelling variants (not varieties/derivatives)?
* [ ] Is the label correct (from the fixed list)?
* [ ] Does it already exist (also check alias overlap)?
* [ ] Is the description short and in the fixed format?