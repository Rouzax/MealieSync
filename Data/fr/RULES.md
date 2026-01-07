# Base d’ingrédients Mealie — RULES.md (FR)

## Objectif
Construire une base d’ingrédients **cohérente, prévisible et facile à parser** :
- noms non ambigus (français)
- règles de découpe claires (frais/séché, entier/moulu, jus/zeste/peau, etc.)
- alias uniquement pour de vrais synonymes/variantes orthographiques
- labels issus d’une liste fixe (vos labels Mealie)

---

## Terminologie Mealie

| Terme      | Concerne    | Exemple                  |
| ---------- | ----------- | ------------------------ |
| **Labels** | Ingrédients | Légumes, Viande, Fromage |
| **Tags**   | Recettes    | Végétarien, Rapide       |

Ce document concerne les **Labels** et la modélisation des **ingrédients**.

---

## Conventions JSON (import-ready)
Un objet ingrédient contient au minimum :
- `name` (string) — nom canonique (français)
- `pluralName` (string) — pluriel courant (ou identique à `name` pour les mass nouns / pluriels figés)
- `description` (string) — court : `définition; usage/préparation.`
- `aliases` (array) — toujours présent, au moins `[]`, éléments `{ "name": "..." }`
- `label` (string) — exactement un label de votre instance Mealie

**Normalisation**
- trim des espaces dans `name`, `pluralName` et les alias ; pas de doubles espaces
- dédoublonner les alias **sans tenir compte de la casse**
- aucun alias identique à `name` ou `pluralName` (sans tenir compte de la casse)
- préférence : **minuscules** (sauf majuscule vraiment standard)

---

## 1. Qu’est-ce qu’un ingrédient ?

### À inclure
- Ingrédients de base (légumes, fruits, viande, herbes, etc.)
- Produits de placard utilisés en cuisine (farine, pâtes, bouillon, sauces)
- Condiments/exhausteurs (sauce soja, moutarde, pâte de piment)
- Ingrédients déjà préparés achetés comme base :
  - maquereau fumé, escalope panée, lamelles de shawarma, amandes grillées

### À exclure
- Préparations/plats que l’on prépare soi-même :
  - purée, overnight oats, soufflé, pâte à beignet, pesto maison
- Plats prêts à consommer (en tant que “plat”) :
  - parfait, sorbet, petits fours
- Marques
- Termes trop génériques sans contexte produit :
  - « jus », « pâte »
- Éléments rares/obscurs (ajouter avec prudence)

---

## 2. Nommage

### 2.1 Nom principal (`name`)
- Utiliser le **nom français courant**
- Utiliser la **forme la plus courante** :
  - généralement au singulier
  - autoriser les noms de produits couramment au pluriel (ex. flocons d’avoine, pâtes)
- Pas de marques
- Éviter les noms étrangers sauf s’ils sont la dénomination la plus courante en français

### 2.2 Qualificatifs de forme/état (parenthèses)
Pour les formes/états qui seraient ambigus autrement, utiliser une notation stable :
- variantes non ambiguës
- parsing simple
- noms compréhensibles pour les cuisiniers

**Règle principale**
`nom de base (qualificatif)`

**Accord grammatical (obligatoire)**
Le qualificatif **s’accorde** en genre et en nombre avec le nom principal de `name` :
- coriandre (fraîche) / coriandre (séchée)
- thym (frais) / thym (séché)
- graines de coriandre (entières) / graines de coriandre (moulues)

Formes usuelles :
- frais / fraîche / frais / fraîches
- séché / séchée / séchés / séchées
- entier / entière / entiers / entières
- moulu / moulue / moulus / moulues

Utiliser les parenthèses pour les découpes fréquentes :
- État : (frais/fraîche), (séché/séchée)
- Mouture : (entier/entière), (moulu/moulue)
- Forme : (en grains), (flocons), (bâtons)
- Agrumes : (jus), (zeste), (peau)

**Exception : poudre comme nom de produit**
Quand la forme la plus naturelle est « X en poudre », l’utiliser comme `name`
(au lieu de `x (moulu/moulue)`), par ex. :
- ail en poudre
- oignon en poudre
- gingembre en poudre
- cannelle en poudre
- paprika en poudre
- piment en poudre

Garder les variantes d’écriture en alias (voir Alias).

**Quand NE PAS utiliser de parenthèses**
- Si le français a un terme produit “figé” qui n’est pas un état/forme :
  - blanc d’œuf, jaune d’œuf, fromage cottage

### 2.3 Pluriel (`pluralName`)
- Utiliser le pluriel courant
- Pour les mass nouns ou pluriels figés (ex. riz, sel, flocons d’avoine) : `pluralName == name` est acceptable
- Pour les variantes avec parenthèses :
  - souvent traité comme mass noun → `pluralName == name`
  - si la parenthèse indique une forme dénombrable, pluraliser si nécessaire :
    - poivre noir (en grain) → poivre noir (en grains)
    - cannelle (bâton) → cannelle (bâtons)

### Exemples de nommage (non-français → français)
| ❌ Incorrect (pas FR)     | ✅ Correct (FR)        |
| ------------------------ | --------------------- |
| maple syrup              | sirop d’érable        |
| thousand island dressing | sauce cocktail        |
| nutritional yeast flakes | levure nutritionnelle |
| mineral water (as name)  | eau minérale          |
| cottage cheese           | fromage cottage       |
| plantain                 | banane plantain       |

---

## 3. Alias (`aliases`)

### 3.1 Qu’est-ce qu’un alias ?
Un alias est un **autre nom pour exactement le même ingrédient** :
- synonyme, traduction, variante orthographique, avec/sans accents, variantes d’espaces/tirets

### 3.2 Alias et pluriels
Le pluriel va dans `pluralName`, pas en alias.

Les alias peuvent inclure singulier et pluriel uniquement si c’est un usage courant.

Exemple :
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

### 3.3 Jamais en alias (toujours des entrées séparées)

* Variétés : golden, gala, etc.
* Produits/formes dérivées : citron (jus) ≠ citron ; citron vert (zeste) ≠ citron vert
* Produits différents : raisins secs ≠ groseilles (et autres fruits secs distincts)
* Préparations : espresso ≠ café ; pulled pork ≠ épaule de porc
* Produits vraiment différents : mozzarella di bufala ≠ mozzarella

### 3.4 Bons exemples d’alias

* Variantes sans accents / fautes fréquentes
* Variantes d’écriture : espaces / tirets

**Variantes “poudre”**

* Si `name` est « X en poudre », ajouter les variantes fréquentes :

  * ail en poudre → poudre d’ail, ail poudre, ail-en-poudre
* Si `name` est une variante entre parenthèses, « X en poudre » peut être un alias seulement si très courant :

  * cannelle (moulue) → alias : cannelle en poudre (si vous n’avez pas choisi cannelle en poudre comme `name`)

**Formes composées modélisées par parenthèses : alias possibles**

* jus de citron → citron (jus)
* zeste de citron → citron (zeste)
* poivre noir en grains → poivre noir (en grains)

**Règle de prudence :** en cas de doute, créer une entrée séparée.

---

## 4. Déduplication & consolidation (règle stricte)

Fusionner si :

* `name` identique (sans tenir compte de la casse), ou
* recouvrement d’alias (sans tenir compte de la casse)

Lors d’une fusion :

* conserver un `name` canonique selon ces règles
* garder la meilleure `description` (courte et claire)
* fusionner + nettoyer les alias
* corriger `pluralName`
* corriger `label`

---

## 5. Découper les ingrédients (règle stricte)

### 5.1 Toujours découper si

* Parties différentes d’un même animal/plante (ex. blanc d’œuf vs jaune d’œuf)
* frais vs séché
* entier vs moulu
* jus/zeste/peau
* formes clairement différentes (en grains/flocons/bâtons)

### 5.2 Convention de nommage

Suffixe entre parenthèses (avec accord) :

* x (frais/fraîche), x (séché/séchée)
* x (entier/entière), x (moulu/moulue)
* x (jus), x (zeste), x (peau)
* x (en grains), x (flocons), x (bâtons)

Utiliser « X en poudre » comme `name` quand c’est le terme produit le plus naturel (voir 2.2).

Déplacer les alias vers la bonne entrée. Supprimer l’ancienne entrée ambiguë.

### 5.3 Exemples

**Herbes & épices**

* coriandre (fraîche) ↔ coriandre (séchée) (si vous modélisez les deux)
* graines de coriandre (entières) ↔ graines de coriandre (moulues)
* gingembre (frais) ↔ gingembre en poudre
* ail (frais) ↔ ail en poudre
* oignon (frais) ↔ oignon en poudre
* cannelle (bâtons) ↔ cannelle en poudre
* noix de muscade (entière) ↔ noix de muscade (moulue)
* poivre noir (en grains) ↔ poivre noir (moulu)
* poivre blanc (en grains) ↔ poivre blanc (moulu)

**Agrumes**

* citron ↔ citron (zeste) ↔ citron (jus)
* citron vert ↔ citron vert (zeste) ↔ citron vert (jus)
* orange ↔ orange (zeste) ↔ orange (jus)

**Œufs**

* œuf, jaune d’œuf, blanc d’œuf (toujours séparés)

**Fromage**

* mozzarella et mozzarella di bufala séparés
* affinages/types séparés (pas d’alias)

---

## 6. Labels

### 6.1 Principes

1. Labelliser ce que c’est **réellement**, pas son usage/origine

   * bouillon de poisson → **Bouillon & arômes** (pas Poisson & fruits de mer)
   * sauce huître → **Sauces & condiments** (pas Poisson & fruits de mer)

2. Fromage séparé des produits laitiers

   * mozzarella, parmesan → **Fromage**
   * lait, yaourt, crème, lait de coco → **Produits laitiers**

3. Sucré = produits sucrés + pâtes à tartiner

   * confiture, miel, sirop, pâte à tartiner, beurre de cacahuète → **Sucré**

4. Charcuterie = viandes transformées

   * jambon, bacon, saucisson, pâté → **Charcuterie**

### 6.2 Erreurs fréquentes

| Ingrédient          | ❌ Mauvais label         | ✅ Bon label             |
| ------------------- | ----------------------- | ----------------------- |
| sauce huître        | Poisson & fruits de mer | Sauces & condiments     |
| bouillon de poisson | Poisson & fruits de mer | Bouillon & arômes       |
| mozzarella          | Produits laitiers       | Fromage                 |
| poudre cappuccino   | Produits laitiers       | Café & thé              |
| flocons d’avoine    | Noix & graines          | Céréales petit-déjeuner |
| sarrasin            | Produits de pâtisserie  | Pâtes, riz & nouilles   |
| raisins secs        | Sucré                   | Fruits                  |
| tofu                | Produits laitiers       | Légumineuses            |
| beurre de cacahuète | Noix & graines          | Sucré                   |
| tzatziki            | Produits laitiers       | Sauces & condiments     |
| houmous             | Légumineuses            | Sauces & condiments     |
| confiture           | Sauces & condiments     | Sucré                   |
| miel                | Produits de pâtisserie  | Sucré                   |

### 6.3 Jeu de labels (exemple : 29 labels)

**Important :** la valeur `label` doit correspondre *exactement* à votre instance Mealie.

#### 🥬 FRAIS

| #   | Label                        | Description                   | Exemples                           |
| --- | ---------------------------- | ----------------------------- | ---------------------------------- |
| 1   | Légumes                      | Légumes frais                 | tomate, oignon, carotte, jalapeño  |
| 2   | Fruits                       | Fruits frais & secs           | pomme, banane, raisins secs        |
| 3   | Herbes fraîches              | Herbes fraîches (non séchées) | basilic, persil, citronnelle       |
| 4   | Pommes de terre & tubercules | Tubercules et assimilés       | pomme de terre, céleri-rave, radis |

#### 🥩 VIANDE & POISSON

| #   | Label                   | Description                      | Exemples                           |
| --- | ----------------------- | -------------------------------- | ---------------------------------- |
| 5   | Viande                  | Viandes crues (bœuf/porc/agneau) | steak, viande hachée, filet mignon |
| 6   | Volaille                | Volaille crue                    | poulet, dinde, canard              |
| 7   | Poisson & fruits de mer | Poissons et fruits de mer        | saumon, crevettes, moules, nori    |
| 8   | Charcuterie             | Viandes transformées             | jambon, bacon, saucisson, pâté     |

#### 🧊 RÉFRIGÉRÉ

| #   | Label             | Description                      | Exemples                                   |
| --- | ----------------- | -------------------------------- | ------------------------------------------ |
| 9   | Produits laitiers | Produits laitiers (hors fromage) | lait, yaourt, crème, lait de coco          |
| 10  | Fromage           | Tous les fromages                | gouda, mozzarella, parmesan, fromage frais |
| 11  | Œufs              | Œufs et parties                  | œuf, jaune d’œuf, blanc d’œuf              |

#### 🍞 PAIN & PETIT-DÉJEUNER

| #   | Label                   | Description                   | Exemples                               |
| --- | ----------------------- | ----------------------------- | -------------------------------------- |
| 12  | Pain & viennoiseries    | Pain et viennoiseries         | pain, croissant, tortilla              |
| 13  | Produits de pâtisserie  | Ingrédients de pâtisserie     | farine, sucre, levure, levure chimique |
| 14  | Céréales petit-déjeuner | Produits céréaliers petit-déj | flocons d’avoine, muesli, granola      |

#### 📦 ÉPICERIE SÈCHE

| #   | Label                 | Description             | Exemples                         |
| --- | --------------------- | ----------------------- | -------------------------------- |
| 15  | Pâtes, riz & nouilles | Féculents secs          | spaghetti, riz, ramen, udon      |
| 16  | Légumineuses          | Haricots/lentilles/pois | pois chiches, lentilles, tofu    |
| 17  | Noix & graines        | Noix et graines         | amandes, noix, graines de sésame |

#### 🧂 ÉPICES & SAUCES

| #   | Label                                | Description              | Exemples                                   |
| --- | ------------------------------------ | ------------------------ | ------------------------------------------ |
| 18  | Herbes & épices                      | Herbes/épices sèches     | cumin, cannelle en poudre, galanga         |
| 19  | Huiles, vinaigres & matières grasses | Corps gras et vinaigres  | huile d’olive, beurre, vinaigre balsamique |
| 20  | Sauces & condiments                  | Sauces et condiments     | ketchup, sauce soja, sambal, pesto         |
| 21  | Bouillon & arômes                    | Bouillons, fonds, arômes | cube de bouillon, fond, glutamate (msg)    |

#### 🍫 SNACKS & SUCRÉ

| #   | Label  | Description                            | Exemples                                                |
| --- | ------ | -------------------------------------- | ------------------------------------------------------- |
| 22  | Snacks | Encas salés                            | chips, popcorn, crackers                                |
| 23  | Sucré  | Produits sucrés incl. pâtes à tartiner | chocolat, bonbons, confiture, miel, beurre de cacahuète |

#### 🥤 BOISSONS

| #   | Label                 | Description              | Exemples                  |
| --- | --------------------- | ------------------------ | ------------------------- |
| 24  | Boissons              | Sodas, jus, eau          | cola, jus d’orange, tonic |
| 25  | Vin                   | Vins y compris fortifiés | vin rouge, xérès, porto   |
| 26  | Bière                 | Toutes bières            | lager, blanche, IPA       |
| 27  | Spiritueux & liqueurs | Distillés/liqueurs       | rhum, whisky, cointreau   |
| 28  | Café & thé            | Boissons chaudes         | café, thé vert, rooibos   |

#### 📍 AUTRE

| #   | Label | Description   | Exemples |
| --- | ----- | ------------- | -------- |
| 29  | Autre | Non classable | divers   |

---

## 7. Descriptions (`description`)

### Format fixe

`[Définition courte]; [usage/préparation].`

### Règles

* court et factuel, pas de marketing
* repère : < ~80 caractères (conservateur)
* 1 caractéristique + 1 usage typique

### Exemples

* Sauce sombre à base d’extrait d’huître; assaisonnement en cuisine asiatique.
* Poisson gras; se cuisine de multiples façons.
* Mélange cajun; épicé avec paprika et piment.

---

## 8. Étapes de traitement (toujours)

1. Valider & normaliser

   * `aliases` toujours présent (au moins `[]`)
   * trim & dédoublonner (sans tenir compte de la casse)
2. Dédupliquer & consolider

   * fusion sur `name` et recouvrement d’alias
3. Découper si nécessaire

   * remplacer les entrées ambiguës par des entrées claires
4. Améliorer

   * corriger pluralName, label, format description
5. Étendre (prudemment, dans le périmètre)

   * uniquement des ingrédients courants de la catégorie
6. Trier

   * ordre alphabétique sur `name`

---

## 9. Checklist

* [ ] Est-ce un ingrédient (pas une préparation/un plat) ?
* [ ] `name` est-il le nom français courant (souvent singulier; pluriels figés autorisés) ?
* [ ] La forme/état est-il non ambigu (sinon découper) ?
* [ ] Les poudres utilisent-elles « X en poudre » quand c’est le terme le plus naturel ?
* [ ] Les alias sont-ils de vrais synonymes/variantes (pas des dérivés/variétés) ?
* [ ] Le label est-il correct (dans la liste) ?
* [ ] L’ingrédient existe-t-il déjà (y compris via recouvrement d’alias) ?
* [ ] La description est-elle courte et au bon format ?