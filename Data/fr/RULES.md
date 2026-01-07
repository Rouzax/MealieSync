# Base d'ingrédients Mealie - Règles et lignes directrices (FR)

## Terminologie Mealie

| Terme                   | Associé à   | Exemple                                        |
| ----------------------- | ----------- | ---------------------------------------------- |
| **Étiquettes** (Labels) | Ingrédients | « Légumes », « Viande », « Produits laitiers » |
| **Tags**                | Recettes    | « Végétarien », « Rapide »                     |

Ce document concerne les **Étiquettes** des ingrédients.

---

## 1) Qu'est-ce qu'un ingrédient ?

### À inclure

* Matières premières (légumes, fruits, viande, herbes, etc.)
* Produits de base du placard utilisés comme ingrédients (farine, pâtes, bouillon)
* Sauces et condiments ajoutés aux plats
* **Ingrédients déjà préparés** achetés prêts à l'emploi comme « briques » de cuisine :

  * maquereau fumé, escalope de poulet panée, émincés de shawarma, amandes grillées

### À ne pas inclure

* **Préparations / plats finis** que vous préparez vous-même :

  * purée de pommes de terre, croquettes, overnight oats, soufflé, pâte à beignets / pâte à crêpes
* **Plats/desserts prêts à consommer** :

  * parfait, sorbet, petit four
* **Marques** :

  * « Philadelphia », « Kiri », « MonChou », « Grape-Nuts », « San Pellegrino »
* **Termes trop génériques** :

  * « jus », « pâte »
* **Objets obscurs/inconnus** (si vous ne savez pas clairement le définir et l'étiqueter) :

  * règle simple : ne l'ajoutez pas

---

## 2) Nommage

### Nom principal (`name`)

* Utiliser le **nom français le plus courant**
* **Par défaut au singulier**, et mettre le pluriel dans `pluralName`

  * *Exception pratique (FR)* : si l'usage est presque toujours au pluriel (ex. **pâtes**, **flocons d'avoine**), gardez la forme la plus naturelle, mais restez cohérent.
* Pas de marques dans le nom principal
* Éviter les noms non français sauf s'ils sont très courants en français (ex. *IPA*, *red velvet*, *gochujang*)

### Pluriel (`pluralName`)

* Utiliser la forme plurielle courante en français

### Exemples

| ❌ Mauvais (non FR / marque / bizarre)            | ✅ Bon (FR courant)                                                |
| ------------------------------------------------ | ----------------------------------------------------------------- |
| maple syrup                                      | sirop d'érable                                                    |
| sirop de Liège (si vous utilisez une version FR) | sirop de Liège                                                    |
| spa blauw                                        | eau minérale                                                      |
| hüttenkäse                                       | cottage cheese *(ou « fromage cottage » si vous préférez)*        |
| plantain                                         | banane plantain                                                   |
| nutritional yeast                                | levure nutritionnelle *(ou « levure nutritionnelle en flocons »)* |

---

## 3) Alias

### Qu'est-ce qu'un alias ?

Un alias est un **autre nom pour exactement le même ingrédient**.

### Alias vs pluriels

**Règle :** le pluriel de `name` va dans `pluralName`, **pas** dans `aliases`.

Les alias peuvent être au singulier **et** au pluriel (et vous pouvez mettre les deux).

**Exemple :**

```json
{
  "name": "pomme de terre",
  "pluralName": "pommes de terre",
  "aliases": [
    { "name": "patate" },
    { "name": "patates" }
  ]
}
```

**Donc pas :**

```json
"aliases": [{ "name": "pommes de terre" }]  ❌
```

### Ne PAS utiliser d'alias pour

* **Variétés/cultivars** : Granny Smith (pomme), Elstar, Jonagold, Conférence (poire)
* **Produits dérivés** : jus de citron, zeste de citron, graines de grenade
* **Ingrédients différents** : bok choy ≠ chou chinois ; raisins secs ≠ groseilles
* **Préparations** : espresso ≠ café ; pulled pork ≠ épaule de porc
* **Variantes** : mozzarella di bufala, bratwurst, chipolata

### OK comme alias

* **Vrais synonymes** : *patate* pour *pomme de terre*
* **Traductions très courantes** : *maïzena* comme alias de *fécule de maïs*
* **Orthographes alternatives** : *balsamico* pour *vinaigre balsamique*
* **Sans diacritiques** : *jalapeno* pour *jalapeño*
* **Variantes d'espaces** : *cube de bouillon de poulet* vs *bouillon-cube de poulet* (si vos recettes mélangent les écritures)

### Règle simple

Si vous hésitez : **créez un ingrédient séparé.**

---

## 4) Scinder les ingrédients

### Règle

**Toujours scinder** quand c'est :

* Une autre partie de l'animal/de la plante
* Frais vs séché
* Entier vs moulu
* Zeste/jus/peau vs fruit entier

Aucune exception : c'est plus simple et plus prévisible.

### Graines / Moulu / Séché / Frais

| Situation                                            | Règle      | Exemple                                     |
| ---------------------------------------------------- | ---------- | ------------------------------------------- |
| Partie différente (feuille vs graine, bulbe vs tige) | **Séparé** | coriandre (feuilles) + graines de coriandre |
| Frais vs séché                                       | **Séparé** | gingembre + gingembre en poudre             |
| Entier vs moulu                                      | **Séparé** | noix de muscade + muscade moulue            |
| Zeste/jus/peau                                       | **Séparé** | citron + zeste de citron + jus de citron    |

### Exemples

**Herbes & épices**

* coriandre ↔ graines de coriandre
* fenouil ↔ graines de fenouil
* gingembre ↔ gingembre en poudre
* ail ↔ ail en poudre
* oignon ↔ oignon en poudre
* paprika (piment) ↔ paprika en poudre
* cannelle ↔ bâton de cannelle
* noix de muscade ↔ muscade moulue
* poivre noir ↔ grains de poivre noir
* poivre blanc ↔ grains de poivre blanc
* cardamome ↔ cardamome moulue
* clou de girofle ↔ girofle moulue

**Fruits**

* citron ↔ zeste de citron ↔ jus de citron
* citron vert ↔ zeste de citron vert ↔ jus de citron vert
* orange ↔ zeste d'orange ↔ jus d'orange

**Volaille**

* poulet → poulet, blanc de poulet, cuisse de poulet, pilon, aile, poulet haché

**Viande**

* porc → porc, filet mignon, longe, épaule
* haché → viande hachée, bœuf haché, porc haché, mélange bœuf/porc

**Œufs**

* œuf, jaune d'œuf, blanc d'œuf (ingrédients séparés, pas des alias)

**Fromage**

* mozzarella et mozzarella di bufala : séparés
* fromages « jeune/affiné/très affiné » : séparés si vous les utilisez différemment

---

## 5) Étiquettes

### Erreurs fréquentes

| Ingrédient                | ❌ Mauvaise étiquette    | ✅ Bonne étiquette               |
| ------------------------- | ----------------------- | ------------------------------- |
| sauce d'huître            | Poisson & fruits de mer | Sauces & condiments             |
| bouillon de poisson       | Poisson & fruits de mer | Bouillons & exhausteurs de goût |
| mozzarella                | Produits laitiers       | Fromage                         |
| poudre cappuccino         | Produits laitiers       | Café & thé                      |
| flocons d'avoine          | Noix & graines          | Céréales du petit-déjeuner      |
| sarrasin                  | Ingrédients pâtisserie  | Pâtes, riz & nouilles           |
| raisins secs              | Produits sucrés         | Fruits                          |
| tofu                      | Produits laitiers       | Légumineuses                    |
| beurre de cacahuète       | Noix & graines          | Produits sucrés                 |
| pâté de foie / liverwurst | Viande                  | Charcuterie                     |
| tzatziki                  | Produits laitiers       | Sauces & condiments             |
| houmous                   | Légumineuses            | Sauces & condiments             |
| confiture                 | Sauces & condiments     | Produits sucrés                 |
| miel                      | Ingrédients pâtisserie  | Produits sucrés                 |

### Étiquettes disponibles (29)

#### 🥬 FRAIS

| #   | Étiquette                             | Description                   | Exemples                           |
| --- | ------------------------------------- | ----------------------------- | ---------------------------------- |
| 1   | **Légumes**                           | Légumes frais                 | tomate, oignon, carotte, jalapeño  |
| 2   | **Fruits**                            | Fruits frais & secs           | pomme, banane, raisins secs        |
| 3   | **Herbes fraîches**                   | Herbes fraîches (non séchées) | basilic, persil, citronnelle       |
| 4   | **Pommes de terre & légumes-racines** | Tubercules et racines         | pomme de terre, céleri-rave, radis |

#### 🥩 VIANDE & POISSON

| #   | Étiquette                   | Description                                     | Exemples                           |
| --- | --------------------------- | ----------------------------------------------- | ---------------------------------- |
| 5   | **Viande**                  | Viande crue (bœuf, porc, agneau)                | steak, viande hachée, filet mignon |
| 6   | **Volaille**                | Volaille crue                                   | poulet, canard, dinde              |
| 7   | **Poisson & fruits de mer** | Poissons et fruits de mer                       | saumon, crevette, moules, nori     |
| 8   | **Charcuterie**             | Viandes transformées (fumées/salées/à tartiner) | jambon, bacon, saucisson, pâté     |

#### 🧊 FRAIS / RÉFRIGÉRÉ

| #   | Étiquette             | Description                      | Exemples                                   |
| --- | --------------------- | -------------------------------- | ------------------------------------------ |
| 9   | **Produits laitiers** | Produits laitiers (hors fromage) | lait, yaourt, crème, lait de coco          |
| 10  | **Fromage**           | Tous les fromages                | comté, mozzarella, parmesan, fromage frais |
| 11  | **Œufs**              | Œufs et parties                  | œuf, jaune d'œuf, blanc d'œuf              |

#### 🍞 PAIN & PETIT-DÉJEUNER

| #   | Étiquette                      | Description                | Exemples                               |
| --- | ------------------------------ | -------------------------- | -------------------------------------- |
| 12  | **Pain & viennoiseries**       | Pain, wraps, viennoiseries | pain, croissant, tortilla              |
| 13  | **Ingrédients pâtisserie**     | Ingrédients de pâtisserie  | farine, sucre, levure chimique, levure |
| 14  | **Céréales du petit-déjeuner** | Céréales/grains du matin   | flocons d'avoine, muesli               |

#### 📦 ÉPICERIE SÈCHE

| #   | Étiquette                 | Description               | Exemples                      |
| --- | ------------------------- | ------------------------- | ----------------------------- |
| 15  | **Pâtes, riz & nouilles** | Féculents secs            | spaghetti, riz, ramen, udon   |
| 16  | **Légumineuses**          | Haricots, lentilles, pois | pois chiches, lentilles, tofu |
| 17  | **Noix & graines**        | Noix et graines           | amande, noix, sésame          |

#### 🧂 ÉPICES & SAUCES

| #   | Étiquette                                | Description               | Exemples                           |
| --- | ---------------------------------------- | ------------------------- | ---------------------------------- |
| 18  | **Herbes & épices**                      | Herbes/épices sèches      | paprika, cannelle, galanga         |
| 19  | **Huiles, vinaigres & matières grasses** | Corps gras et acides      | huile d'olive, vinaigre balsamique |
| 20  | **Sauces & condiments**                  | Sauces et assaisonnements | ketchup, sauce soja, sambal, pesto |
| 21  | **Bouillons & exhausteurs de goût**      | Bouillon, fond, umami     | bouillon, fond, Maggi              |

#### 🍫 SNACKS & SUCRÉ

| #   | Étiquette           | Description                     | Exemples                                                |
| --- | ------------------- | ------------------------------- | ------------------------------------------------------- |
| 22  | **Snacks**          | Grignotages salés               | chips, crackers, popcorn                                |
| 23  | **Produits sucrés** | Sucré, sirops, pâtes à tartiner | chocolat, bonbons, confiture, miel, beurre de cacahuète |

#### 🥤 BOISSONS

| #   | Étiquette                 | Description               | Exemples                  |
| --- | ------------------------- | ------------------------- | ------------------------- |
| 24  | **Boissons**              | Soda, jus, eau            | cola, jus d'orange, tonic |
| 25  | **Vin**                   | Vin et vins fortifiés     | vin rouge, xérès, porto   |
| 26  | **Bière**                 | Toutes bières             | lager, blanche, IPA       |
| 27  | **Spiritueux & liqueurs** | Alcools forts et liqueurs | rhum, whisky, Cointreau   |
| 28  | **Café & thé**            | Boissons chaudes          | café, thé vert, rooibos   |

#### 📍 AUTRE

| #   | Étiquette | Description | Exemples              |
| --- | --------- | ----------- | --------------------- |
| 29  | **Autre** | Inclassable | (rarement nécessaire) |

### Principes d'étiquetage

1. **Étiqueter selon ce que c'est**, pas selon l'origine

   * bouillon de poisson → **Bouillons & exhausteurs de goût** (pas Poisson)
   * sauce d'huître → **Sauces & condiments** (pas Poisson)

2. **Fromage toujours séparé des Produits laitiers**

   * mozzarella, parmesan, fromage frais → **Fromage**
   * yaourt, lait de coco → **Produits laitiers**

3. **Produits sucrés = sucré, y compris les tartinables**

   * confiture, miel, sirops, vermicelles sucrés, beurre de cacahuète → **Produits sucrés**
   * chocolat, bonbons → **Produits sucrés**

4. **Charcuterie = viande transformée (y compris à tartiner)**

   * jambon, bacon, saucisson → **Charcuterie**
   * pâté, rillettes, liverwurst → **Charcuterie**

---

## 6) Descriptions

### Format

`[Définition courte] ; [usage/préparation typique].`

### Exemples

* « Sauce sombre à base d'extrait d'huître ; assaisonnement umami en cuisine chinoise. »
* « Poisson gras à chair rosée ; se prépare de nombreuses façons. »
* « Mélange d'épices cajun ; piquant avec paprika et cayenne. »

### Conseils

* Court et informatif
* Donner le trait distinctif
* Mentionner l'usage typique si utile

---

## 7) Checklist avant d'ajouter un ingrédient

* [ ] Est-ce un vrai ingrédient (pas une préparation/un plat) ?
* [ ] Le nom principal est-il du français courant ?
* [ ] Les alias sont-ils de vrais synonymes (le pluriel de `name` va dans `pluralName`) ?
* [ ] L'étiquette est-elle la bonne ?
* [ ] L'ingrédient n'existe-t-il pas déjà (vérifier aussi les alias) ?
* [ ] Ce n'est pas une marque ?
* [ ] Frais/séché et entier/moulu sont-ils bien séparés ?
