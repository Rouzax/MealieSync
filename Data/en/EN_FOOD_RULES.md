# Mealie Ingredient Database: Food Rules (EN)

## Goal
To maintain an ingredient database that is **consistent, predictable, and parse-friendly**[cite: 10]:
- Unambiguous names (English, singular)[cite: 10].
- Clear splitting rules (fresh/dried, whole/ground, etc.)[cite: 10].
- Strict UUID mapping to the foundational Dutch (NL) dataset[cite: 1].
- Labels strictly applied from the predefined `Labels.json` list[cite: 10].

---

## 1. Absolute UUID Integrity (Critical)
Because the Dutch (`Data/nl/`) dataset is designated as the absolute source of truth for base culinary concepts and database IDs, **every entry in `Data/en/` MUST retain the exact `id` / `uuid` from its original twin in `Data/nl/`**[cite: 1]. 
- **Never** generate new UUIDs for existing or translated items[cite: 1].
- If adding a completely new ingredient, it must be added to the Dutch dataset first, and then translated to English sharing the new UUID.

---

## 2. Naming & Syntax Standardization

### 2.1 Primary Name (`name`)
- Always use standard US/UK culinary English[cite: 1].
- Always use the **singular** form[cite: 10].
- Avoid brand names[cite: 10].

### 2.2 Qualifiers for State/Form
To prevent parsing collisions and keep variations clear, we use a strict parenthetical suffix syntax[cite: 1]:
`base name (qualifier)`

**Hard rule:** Maximum of **1** qualifier per `name`[cite: 10].
- **Parentheses Syntax:** Use parentheses `()` for form/state qualifiers (e.g., `(fresh)`, `(ground)`, `(dried)`, `(zest)`)[cite: 1]. This explicitly overrides the Dutch standard of using square brackets `[]`[cite: 1].

**Allowed Qualifiers Include:**
- **State:** `(fresh)`, `(dried)`
- **Grind:** `(whole)`, `(ground)`
- **Form:** `(peppercorns)`, `(flakes)`, `(stick)`
- **Derived:** `(juice)`, `(zest)`, `(peel)`
- **Pantry/Storage:** `(canned)`, `(frozen)`, `(pickled)`
- **Preparation:** `(roasted)`, `(smoked)`

**Exception (Powders as standard names):**
If "X powder" is the standard culinary term, use it as the base name instead of a qualifier[cite: 10]. 
- ✅ `garlic powder` (Instead of `garlic (ground)`)
- ✅ `onion powder`

### 2.3 The "Fresh" Produce Rule
- For the `Vegetables` and `Fruit` labels, the base name inherently implies "fresh"[cite: 10]. 
- **Never** add a `(fresh)` qualifier to raw produce[cite: 10]. 
  - ✅ `lemon`, `tomato`, `onion`
  - ❌ `lemon (fresh)`, `tomato (fresh)`
- Modified forms of produce *do* take qualifiers: `tomato (canned)`, `lemon (juice)`, `mango (dried)`[cite: 10].

### 2.4 Plurals (`pluralName`)
- Ensure standard English pluralization (e.g., `potato` -> `potatoes`, `squash` -> `squashes`)[cite: 1].
- Uncountable/mass nouns (e.g., `flour`, `rice`) should leave the plural identical to the singular name[cite: 1, 10].
- Pluralize countable qualifiers where logical: `cinnamon (sticks)`, `black pepper (peppercorns)`[cite: 10].

---

## 3. Aliases (`aliases`)
An alias is an alternative name for the exact same ingredient[cite: 10].

**What belongs in Aliases:**
- Synonyms or regional variants (e.g., `cilantro` as an alias for `coriander (fresh)`).
- Regional culinary terms mapped from the original Dutch/French (e.g., storing `procureur` as an alias under the standard English translation `pork collar`)[cite: 1].
- Spelling variations without diacritics (e.g., `jalapeno` for `jalapeño`)[cite: 10].

**What does NOT belong in Aliases:**
- Distinct varieties (e.g., Granny Smith is not an alias for Apple)[cite: 10].
- Preparations (e.g., Pulled pork is not an alias for Pork shoulder)[cite: 10].
- Terms that collide with primary entries in other files (e.g., reserving `almond paste` strictly for Baking Goods and removing it from Sweets)[cite: 1].

---

## 4. Descriptions (`description`)
Format strictly as: `[Short definition]; [typical use/preparation].`[cite: 10]
- Must contain exactly **one semicolon (;)**[cite: 10].
- Keep under 100 characters[cite: 10].
- Short, informative, no marketing text[cite: 10]. 
*Example: "Thick English cream; for scones and desserts."*