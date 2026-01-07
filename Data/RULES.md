# Mealie Ingredients Database — Rules & Guidelines

## Mealie terminology

| Term       | Used for    | Example                      |
| ---------- | ----------- | ---------------------------- |
| **Labels** | Ingredients | "Vegetable", "Meat", "Dairy" |
| **Tags**   | Recipes     | "Vegetarian", "Quick"        |

This document is about **Labels** for ingredients.

---

## 1. What counts as an ingredient?

### Include

* Basic raw materials (vegetables, fruit, meat, herbs, etc.)
* Pantry staples used as ingredients (flour, pasta, stock/bouillon)
* Sauces and condiments added to dishes
* **Pre-prepared ingredients** that you buy ready-to-use as building blocks:
  * smoked mackerel, breaded chicken schnitzel, shawarma strips, roasted almonds

### Do not include

* **Preparations / finished dishes** you make yourself:
  * mashed potatoes, croquettes, overnight oats, soufflé, batter
* **Ready-to-eat dishes/desserts**:
  * parfait, sorbet, petit four
* **Brand names**:
  * "Philadelphia cream cheese", "Kiri", "MonChou", "Grape-Nuts", "San Pellegrino"
* **Overly generic terms**:
  * "juice", "dough"
* **Obscure/unknown items** (if you're not sure what it is or it's extremely niche):
  * (rule of thumb) don't add it unless you can clearly define and label it

---

## 2. Naming

### Primary name (`name`)

* Always use the **most common English name**
* Always **singular** (e.g., *potato*, not *potatoes*) — use `pluralName` for plurals
* No brand names as the primary name
* Avoid non-English names unless they're widely used in English (e.g., *IPA*, *red velvet*, *gochujang*)

### Plural (`pluralName`)

* Use the common English plural form

### Examples

| ❌ Wrong (non-English / brand / awkward) | ✅ Right (common English) |
| --------------------------------------- | ------------------------ |
| ahornsiroop                             | maple syrup              |
| sirop de Liège                          | Liège syrup              |
| spa blauw                               | mineral water            |
| hüttenkäse                              | cottage cheese           |
| bakbanaan                               | plantain                 |
| edelgistvlokken                         | nutritional yeast flakes |

---

## 3. Aliases

### What is an alias?

An alias is an **alternative name for the exact same ingredient**.

### Aliases vs plurals

**Rule:** the plural of `name` belongs in `pluralName`, **not** in `aliases`.

Aliases *may* be plural (and you may include both singular + plural forms of the alias).

**Example:**

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

| Field        | Value       | Notes                   |
| ------------ | ----------- | ----------------------- |
| `name`       | potato      | Primary name (singular) |
| `pluralName` | potatoes    | Plural of `name`        |
| `aliases`    | spud, spuds | Synonym + its plural    |

**So not:**

```json
"aliases": [{ "name": "potatoes" }]  ❌
```

### Do NOT use aliases for

* **Varieties/cultivars**: Granny Smith (apple), Elstar, Jonagold, Conference (pear)
* **Derived products**: lemon juice, lime zest, pomegranate seeds
* **Different ingredients**: bok choy ≠ Chinese cabbage; currants ≠ raisins
* **Preparations**: espresso ≠ coffee; pulled pork ≠ pork shoulder
* **Variants**: buffalo mozzarella, bratwurst, chipolata

### OK to use aliases for

* **True synonyms**: *spud* for *potato*
* **Translations commonly used in English**: *maizena* as an alias for *cornstarch*
* **Alternate spellings**: *balsamico* for *balsamic vinegar*
* **No-diacritic spellings**: *jalapeno* for *jalapeño*
* **Spacing variants**: *chicken stock cube* for *chicken stockcube* (if both appear in your recipes)

### Rule of thumb

If you're unsure: **make it a separate ingredient.**

---

## 4. Splitting ingredients

### Rule

**Always split** when it's:

* Different parts of the same animal/plant
* Fresh vs dried
* Whole vs ground
* Zest/juice/peel vs the whole fruit

No exceptions — it keeps things simple and predictable.

### Seed / Ground / Dried / Fresh

| Situation                                         | Rule         | Example                               |
| ------------------------------------------------- | ------------ | ------------------------------------- |
| Different plant part (leaf vs seed, bulb vs leaf) | **Separate** | coriander (cilantro) + coriander seed |
| Fresh vs dried                                    | **Separate** | ginger + ginger powder                |
| Whole vs ground                                   | **Separate** | nutmeg + ground nutmeg                |
| Zest/juice/peel                                   | **Separate** | lemon + lemon zest + lemon juice      |

### Examples

**Herbs & spices**

* coriander/cilantro ↔ coriander seed
* fennel ↔ fennel seed
* ginger ↔ ginger powder
* garlic ↔ garlic powder
* onion ↔ onion powder
* paprika pepper ↔ paprika powder
* cinnamon ↔ cinnamon stick
* nutmeg ↔ ground nutmeg
* black pepper ↔ black peppercorns
* white pepper ↔ white peppercorns
* cardamom ↔ ground cardamom
* clove ↔ ground clove

**Fruit**

* lemon ↔ lemon zest ↔ lemon juice
* lime ↔ lime zest ↔ lime juice
* orange ↔ orange zest ↔ orange juice

**Poultry**

* chicken → chicken, chicken breast, chicken thigh, drumstick, wing, ground chicken

**Meat**

* pork → pork, pork tenderloin, pork loin, pork shoulder
* ground meat → ground meat, ground beef, ground pork, mixed ground meat

**Eggs**

* egg, egg yolk, egg white (separate ingredients, not aliases)

**Cheese**

* mozzarella and buffalo mozzarella: separate
* young/mild, aged, extra-aged cheeses: separate (if you use them distinctly)

---

## 5. Labels

### Common mistakes

| Ingredient        | ❌ Wrong label       | ✅ Right label           |
| ----------------- | ------------------- | ----------------------- |
| oyster sauce      | Fish & Seafood      | Sauces & Condiments     |
| fish stock        | Fish & Seafood      | Stock & Flavor Boosters |
| mozzarella        | Dairy               | Cheese                  |
| cappuccino powder | Dairy               | Coffee & Tea            |
| oats / oatmeal    | Nuts & Seeds        | Breakfast Cereals       |
| buckwheat         | Baking Essentials   | Pasta, Rice & Noodles   |
| raisins           | Sweets              | Fruit                   |
| tofu              | Dairy               | Legumes                 |
| peanut butter     | Nuts & Seeds        | Sweets                  |
| liverwurst        | Meat                | Processed Meats         |
| tzatziki          | Dairy               | Sauces & Condiments     |
| hummus            | Legumes             | Sauces & Condiments     |
| jam               | Sauces & Condiments | Sweets                  |
| honey             | Baking Essentials   | Sweets                  |

### Available labels (29)

#### 🥬 FRESH

| #   | Label                          | Description             | Examples                        |
| --- | ------------------------------ | ----------------------- | ------------------------------- |
| 1   | **Vegetables**                 | Fresh vegetables        | tomato, onion, carrot, jalapeño |
| 2   | **Fruit**                      | Fresh & dried fruit     | apple, banana, raisins          |
| 3   | **Fresh Herbs**                | Fresh herbs (not dried) | basil, parsley, lemongrass      |
| 4   | **Potatoes & Root Vegetables** | Tubers and root veg     | potato, celeriac, radish        |

#### 🥩 MEAT & FISH

| #   | Label               | Description                  | Examples                             |
| --- | ------------------- | ---------------------------- | ------------------------------------ |
| 5   | **Meat**            | Raw meat (beef, pork, lamb)  | steak, mince, pork tenderloin        |
| 6   | **Poultry**         | Raw poultry                  | chicken, duck, turkey                |
| 7   | **Fish & Seafood**  | Fish and shellfish           | salmon, shrimp, mussels, nori        |
| 8   | **Processed Meats** | Cured/smoked/deli/spreadable | ham, bacon, salami, pâté, liverwurst |

#### 🧊 CHILLED

| #   | Label      | Description                      | Examples                                  |
| --- | ---------- | -------------------------------- | ----------------------------------------- |
| 9   | **Dairy**  | Milk-based products (not cheese) | milk, yogurt, cream, coconut milk         |
| 10  | **Cheese** | All cheeses                      | gouda, mozzarella, parmesan, cream cheese |
| 11  | **Eggs**   | Eggs and parts                   | egg, egg yolk, egg white                  |

#### 🍞 BREAD & BREAKFAST

| #   | Label                 | Description              | Examples                            |
| --- | --------------------- | ------------------------ | ----------------------------------- |
| 12  | **Bread & Pastries**  | Bread, wraps, pastries   | bread, croissant, tortilla          |
| 13  | **Baking Essentials** | Baking ingredients       | flour, sugar, baking powder, yeast, |
| 14  | **Breakfast Cereals** | Breakfast grains/cereals | oats, muesli                        |

#### 📦 DRY GOODS

| #   | Label                     | Description          | Examples                     |
| --- | ------------------------- | -------------------- | ---------------------------- |
| 15  | **Pasta, Rice & Noodles** | Dry carbs            | spaghetti, rice, ramen, udon |
| 16  | **Legumes**               | Beans, lentils, peas | chickpeas, lentils, tofu     |
| 17  | **Nuts & Seeds**          | Nuts and seeds       | almond, walnut, sesame seed  |

#### 🧂 SPICES & SAUCES

| #   | Label                       | Description                 | Examples                          |
| --- | --------------------------- | --------------------------- | --------------------------------- |
| 18  | **Herbs & Spices**          | Dried herbs and spices      | paprika, cinnamon, galangal       |
| 19  | **Oils, Vinegars & Fats**   | Fats and acids              | olive oil, balsamic vinegar       |
| 20  | **Sauces & Condiments**     | Sauces and flavorings       | ketchup, soy sauce, sambal, pesto |
| 21  | **Stock & Flavor Boosters** | Stock, fond, umami boosters | stock, bouillon, Maggi            |

#### 🍫 SNACKS & SWEET

| #   | Label      | Description                     | Examples                                    |
| --- | ---------- | ------------------------------- | ------------------------------------------- |
| 22  | **Snacks** | Savory snacks                   | chips, prawn crackers, popcorn              |
| 23  | **Sweets** | Sweet products, syrups, spreads | chocolate, candy, jam, honey, peanut butter |

#### 🥤 DRINKS

| #   | Label                  | Description               | Examples                   |
| --- | ---------------------- | ------------------------- | -------------------------- |
| 24  | **Drinks**             | Soft drinks, juice, water | cola, orange juice, tonic  |
| 25  | **Wine**               | Wine and fortified wine   | red wine, sherry, port     |
| 26  | **Beer**               | All beers                 | lager, wheat beer, IPA     |
| 27  | **Spirits & Liqueurs** | Distilled & liqueurs      | rum, whisky, Cointreau     |
| 28  | **Coffee & Tea**       | Hot drinks                | coffee, green tea, rooibos |

#### 📍 OTHER

| #   | Label     | Description           | Examples                         |
| --- | --------- | --------------------- | -------------------------------- |
| 29  | **Other** | Doesn't fit elsewhere | (anything truly uncategorisable) |

### Label principles

1. **Label what it IS**, not where it comes from
   * fish stock → **Stock & Flavor Boosters** (not Fish & Seafood)
   * oyster sauce → **Sauces & Condiments** (not Fish & Seafood)

2. **Cheese is always separate from Dairy**
   * mozzarella, parmesan, cream cheese → **Cheese**
   * yogurt, coconut milk → **Dairy**

3. **Sweets = sweet products, including spreads**
   * jam, honey, syrups, sprinkles, peanut butter → **Sweets**
   * chocolate, candy → **Sweets**

4. **Processed Meats = cured/processed meats (including spreads)**
   * ham, bacon, salami → **Processed Meats**
   * pâté, liverwurst → **Processed Meats**

---

## 6. Descriptions

### Format

`[Short definition]; [typical use/prep].`

### Examples

* "Dark sauce made from oyster extract; savory seasoning in Chinese cooking."
* "Fatty fish with pink flesh; versatile for many preparations."
* "Spice blend for Cajun dishes; spicy with paprika and cayenne."

### Guidelines

* Keep it short and informative
* Mention defining characteristics
* Mention typical use when relevant

---

## 7. Summary checklist (before adding an ingredient)

- [ ] Is it truly an ingredient (not a dish/preparation)?
- [ ] Is the primary name common English?
- [ ] Are aliases true synonyms (plural of `name` goes in `pluralName`)?
- [ ] Is it in the correct label?
- [ ] Does it already exist (also check aliases)?
- [ ] Is it not a brand name?
- [ ] Are fresh/dried and whole/ground split correctly?
