# Mealie Ingredient Database: Food Rules (EN)

## Goal
To maintain an ingredient database that is **consistent, predictable, and parse-friendly**:
- Unambiguous names (English, singular).
- Clear splitting rules (fresh/dried, whole/ground, etc.).
- Strict UUID mapping to the foundational Dutch (NL) dataset.
- Labels strictly applied from the predefined `Labels.json` list.

---

## 1. Absolute UUID Integrity (Critical)
Because the Dutch (`Data/nl/`) dataset is designated as the absolute source of truth for base culinary concepts and database IDs, **every entry in `Data/en/` MUST retain the exact `id` / `uuid` from its original twin in `Data/nl/`**. 
- **Never** generate new UUIDs for existing or translated items.
- If adding a completely new ingredient, it must be added to the Dutch dataset first, and then translated to English sharing the new UUID.

---

## 2. Naming & Syntax Standardization

### 2.1 Primary Name (`name`)
- Always use standard US/UK culinary English.
- Always use the **singular** form.
- Avoid brand names.

### 2.2 Qualifiers for State/Form
To prevent parsing collisions and keep variations clear, we use a strict parenthetical suffix syntax:
`base name (qualifier)`

**Hard rule:** Maximum of **1** qualifier per `name`.
- **Parentheses Syntax:** Use parentheses `()` for form/state qualifiers (e.g., `(fresh)`, `(ground)`, `(dried)`, `(zest)`). This explicitly overrides the Dutch standard of using square brackets `[]`.

**Allowed Qualifiers Include:**
- **State:** `(fresh)`, `(dried)`
- **Grind:** `(whole)`, `(ground)`
- **Form:** `(peppercorns)`, `(flakes)`, `(stick)`
- **Derived:** `(juice)`, `(zest)`, `(peel)`
- **Pantry/Storage:** `(canned)`, `(frozen)`, `(pickled)`
- **Preparation:** `(roasted)`, `(smoked)`

**Exception (Powders as standard names):**
If "X powder" is the standard culinary term, use it as the base name instead of a qualifier. 
- ✅ `garlic powder` (Instead of `garlic (ground)`)
- ✅ `onion powder`

### 2.3 The "Fresh" Produce Rule
- For the `Vegetables` and `Fruit` labels, the base name inherently implies "fresh". 
- **Never** add a `(fresh)` qualifier to raw produce. 
  - ✅ `lemon`, `tomato`, `onion`
  - ❌ `lemon (fresh)`, `tomato (fresh)`
- Modified forms of produce *do* take qualifiers: `tomato (canned)`, `lemon (juice)`, `mango (dried)`.

### 2.4 Plurals (`pluralName`)
- Ensure standard English pluralization (e.g., `potato` -> `potatoes`, `squash` -> `squashes`).
- Uncountable/mass nouns (e.g., `flour`, `rice`) should leave the plural identical to the singular name.
- Pluralize countable qualifiers where logical: `cinnamon (sticks)`, `black pepper (peppercorns)`.

---

## 3. Aliases (`aliases`)
An alias is an alternative name for the exact same ingredient.

**What belongs in Aliases:**
- Synonyms or regional variants (e.g., `cilantro` as an alias for `coriander (fresh)`).
- Regional culinary terms mapped from the original Dutch/French (e.g., storing `procureur` as an alias under the standard English translation `pork collar`).
- Spelling variations without diacritics (e.g., `jalapeno` for `jalapeño`).

**What does NOT belong in Aliases:**
- Distinct varieties (e.g., Granny Smith is not an alias for Apple).
- Preparations (e.g., Pulled pork is not an alias for Pork shoulder).
- Terms that collide with primary entries in other files (e.g., reserving `almond paste` strictly for Baking Goods and removing it from Sweets).

---

## 4. Descriptions (`description`)
Format strictly as: `[Short definition]; [typical use/preparation].`
- Must contain exactly **one semicolon (;)**.
- Keep under 100 characters.
- Short, informative, no marketing text. 
*Example: "Thick English cream; for scones and desserts."*