# Mealie Ingrediënten Database — RULES.md

## Doel
Een ingrediënten-database die **consistent, voorspelbaar en parse-vriendelijk** is:
- eenduidige namen (NL, enkelvoud)
- heldere splits-regels (vers/gedroogd, heel/gemalen, sap/rasp/schil, etc.)
- aliases alleen voor echte synoniemen/spellingvarianten
- labels altijd uit de vaste lijst

---

## Mealie terminologie

| Term       | Gekoppeld aan | Voorbeeld               |
| ---------- | ------------- | ----------------------- |
| **Labels** | Ingrediënten  | Groente, Vlees, Kaas    |
| **Tags**   | Recepten      | Vegetarisch, Snel klaar |

Dit document gaat over **Labels** en modellering van **ingrediënten**.

---

## JSON-conventies (import-ready)
Een ingrediënt-object bevat minimaal:
- `name` (string) — canonieke naam (NL, enkelvoud)
- `pluralName` (string) — gangbaar meervoud (of gelijk aan `name` bij mass nouns)
- `description` (string) — kort: `definitie; gebruik/bereiding.`
- `aliases` (array) — altijd aanwezig, minstens `[]`, items als `{ "name": "..." }`
- `label` (string) — exact één van de labels in deze file

**Normalisatie:**
- `name`, `pluralName`, aliases: trim spaties; geen dubbele spaties
- dedupe aliases **case-insensitive**
- geen alias die exact gelijk is aan `name` of `pluralName` (case-insensitive)
- voorkeur: **lowercase** voor ingrediënten (tenzij een ingeburgerde eigennaam echt nodig is)

---

## 1. Wat is een ingrediënt?

### Wel opnemen
- Basisgrondstoffen (groenten, fruit, vlees, kruiden, etc.)
- Halffabricaten die als ingrediënt gebruikt worden (bloem, pasta, bouillon, sauzen)
- Condimenten/smaakmakers (sojasaus, mosterd, sambal)
- Voorbewerkte ingrediënten die je koopt als basis:
  - gerookte makreel, kipschnitzel, shoarmareepjes, geroosterde amandelen

### Niet opnemen
- Bereidingen/eindproducten die je zelf maakt:
  - aardappelpuree, overnight oats, soufflé, beslag, zelfgemaakte pesto
- Kant-en-klare gerechten (als “gerecht”):
  - parfait, sorbet, petit-four
- Merknamen:
  - campina roomkaas, kiri, monchou, spa blauw, grape-nuts
- Te generieke termen zonder productcontext:
  - sap, deeg
- Obscure/onbekende items (conservatief toevoegen)

---

## 2. Naamgeving

### 2.1 Primaire naam (`name`)
- Altijd de **gangbare Nederlandse naam**
- Altijd **enkelvoud**
- Geen merknamen
- Geen Engelse namen tenzij echt ingeburgerd als productnaam (conservatief)

### 2.2 Kwalificaties voor vorm/toestand
Voor vormen/toestanden die anders ambigu zijn, gebruiken we een vaste notatie. Doel:
- varianten zijn eenduidig
- parsing is eenvoudig
- namen blijven herkenbaar voor koks

**Hoofdregel (suffix in vierkante haken):**
`basisnaam [kwalificatie]`

Gebruik dit voor duidelijke vormen/toestanden:
- Toestand: `[vers]`, `[gedroogd]`
- Maalvorm: `[heel]`, `[gemalen]`
- Specifieke vorm: `[korrel]`, `[vlokken]`, `[stokje]`
- Afgeleide vorm: `[sap]`, `[rasp]`, `[schil]`

**Uitzondering (poeder als productnaam):**
Als “Xpoeder” de gangbare en herkenbare productnaam is, kies dan die samenstelling als `name`
(in plaats van `x [gemalen]`), bijvoorbeeld:
- `knoflookpoeder`
- `uienpoeder`
- `gemberpoeder`
- `kaneelpoeder`
- `paprikapoeder`
- `chilipoeder`

Houd de alternatieve schrijfwijze als alias (zie Aliases).

**Wanneer géén vierkante haken?**
- Als de gangbare productnaam een vaste samenstelling is die géén vorm/toestand-kwalificatie is:
  - `kipfilet`, `kippendij`, `eidooier`, `eiwit`, `hüttenkäse`, `filet americain`

### 2.3 Meervoud (`pluralName`)
- Gebruik de **gangbare meervoudsvorm**
- Bij “mass nouns” (bijv. rijst, zout) mag: `pluralName == name`
- Bij vierkante-haken-varianten:
  - vaak ook mass noun → `pluralName == name` (bv. `koriander [vers]`)
  - telbaar in vierkante haken pluraliseren waar logisch:
    - `zwarte peper [korrel]` → `zwarte peper [korrels]`
    - `kaneel [stokje]` → `kaneel [stokjes]`

### Naamvoorbeelden
| ❌ Fout                   | ✅ Goed          |
| ------------------------ | --------------- |
| maple syrup              | ahornsiroop     |
| sirop de Liège           | luikse stroop   |
| thousand island dressing | cocktailsaus    |
| nutritional yeast        | edelgistvlokken |
| spa blauw                | mineraalwater   |
| cottage cheese           | hüttenkäse      |
| plantain                 | bakbanaan       |

---

## 3. Aliassen (`aliases`)

### 3.1 Wat is een alias?
Een alias is een **alternatieve naam voor exact hetzelfde ingrediënt**:
- synoniem, vertaling, spellingvariant, met/zonder diacritics, met/zonder spatie/koppelteken

### 3.2 Aliassen en meervouden
Het meervoud van `name` hoort in `pluralName`, niet als alias.

Aliassen mogen wél zowel enkelvoud als meervoud bevatten als dat in het wild voorkomt.

Voorbeeld:
```json
{
  "name": "aardappel",
  "pluralName": "aardappelen",
  "aliases": [
    { "name": "pieper" },
    { "name": "piepers" }
  ]
}
```

### 3.3 Niet als alias (altijd aparte entries)

* Variëteiten: elstar, conference, jonagold
* Afgeleide producten/vormen: citroen [sap] ≠ citroen; limoen [rasp] ≠ limoen
* Andere producten: krenten ≠ rozijnen
* Bereidingen: espresso ≠ koffie; pulled pork ≠ varkensschouder
* Varianten die echt ander product zijn: buffelmozzarella ≠ mozzarella

### 3.4 Wel als alias

* Synoniemen: `kroot` voor biet
* Vertalingen: `tarragon` voor dragon
* Zonder diacritics: `mais` voor `maïs`, `jalapeno` voor `jalapeño`
* Spatie-/koppeltekenvarianten: `kippenbouillon blokje` voor `kippenbouillonblokje`

**Poeder-varianten:**

* Als `name` een poeder-samenstelling is, voeg veelvoorkomende varianten toe als alias:

  * `knoflook poeder`, `knoflook-poeder`
* Als `name` een vierkante-haken-variant is, mag de poeder-samenstelling als alias waar gangbaar:

  * `kaneel [gemalen]` — alias: `kaneelpoeder` (als je niet voor `kaneelpoeder` als `name` kiest)

**Samenstellingen die we met vierkante haken modelleren mogen als alias:**

* `citroensap` → bij `citroen [sap]`
* `citroenrasp` → bij `citroen [rasp]`
* `zwarte peperkorrels` → bij `zwarte peper [korrel]`

**Twijfelregel:** als je twijfelt, maak een apart ingrediënt.

---

## 4. Dedupliceren & consolideren (hard)

Samenvoegen als:

* `name` gelijk is (case-insensitive), of
* aliases elkaar overlappen (case-insensitive)

Bij merge:

* kies 1 canonieke `name` volgens deze rules
* behoud beste (kortste/helderste) `description`
* voeg aliases samen + opschonen
* fix `pluralName`
* fix `label`

---

## 5. Splitsen van ingrediënten (hard rule)

### 5.1 Altijd splitsen bij

* Verschillende delen van hetzelfde dier/plant (bv. eiwit vs eidooier)
* vers vs gedroogd
* heel vs gemalen
* sap/rasp/schil
* duidelijke vormverschillen (korrel/vlokken/stokje)

Dit houdt het voorspelbaar en voorkomt ambiguïteit.

### 5.2 Naamconventie bij splitsen

Gebruik suffix in vierkante haken:

* `x [vers]`, `x [gedroogd]`
* `x [heel]`, `x [gemalen]`
* `x [sap]`, `x [rasp]`, `x [schil]`
* `x [korrel]`, `x [vlokken]`, `x [stokje]`

Gebruik poeder-samenstellingen als `name` wanneer dat de gangbare productnaam is (zie 2.2).

Verplaats aliases naar het juiste gesplitste item. Verwijder de oude ambigue entry.

### 5.3 Voorbeelden

**Kruiden & specerijen**

* `koriander [vers]` ↔ `koriander [gedroogd]` (alleen als beide nodig zijn)
* `korianderzaad [heel]` ↔ `korianderzaad [gemalen]`
* `gember [vers]` ↔ `gemberpoeder`
* `knoflook [vers]` ↔ `knoflookpoeder`
* `ui [vers]` ↔ `uienpoeder`
* `kaneel [stokje]` ↔ `kaneelpoeder`
* `nootmuskaat [heel]` ↔ `nootmuskaat [gemalen]`
* `zwarte peper [korrel]` ↔ `zwarte peper [gemalen]` (alias: `zwarte peperkorrels`)
* `witte peper [korrel]` ↔ `witte peper [gemalen]`

**Citrus**

* `citroen` ↔ `citroen [rasp]` ↔ `citroen [sap]`
* `limoen` ↔ `limoen [rasp]` ↔ `limoen [sap]`
* `sinaasappel` ↔ `sinaasappel [rasp]` ↔ `sinaasappel [sap]`

**Eieren**

* `ei`, `eidooier`, `eiwit` (altijd apart)

**Kaas**

* `mozzarella` en `buffelmozzarella` apart
* `jonge kaas`, `belegen kaas`, `oude kaas` apart (geen aliassen)

---

## 6. Labels

### 6.1 Labelprincipes

1. Label op wat het **IS**, niet op herkomst/toepassing

   * visbouillon → Bouillon & Smaakmakers (niet Vis)
   * oestersaus → Sauzen & Condimenten (niet Vis)

2. Kaas altijd apart van Zuivel

   * mozzarella, parmigiano → Kaas
   * melk, yoghurt, room, kokosmelk → Zuivel

3. Zoetwaren = zoete producten inclusief broodbeleg

   * jam, honing, stroop, hagelslag, pindakaas → Zoetwaren

4. Vleeswaren = bewerkt vlees (ook smeerbaar)

   * ham, bacon, salami, paté, leverworst, filet americain → Vleeswaren

### 6.2 Veelgemaakte fouten

| Ingrediënt       | ❌ Fout               | ✅ Goed                 |
| ---------------- | -------------------- | ---------------------- |
| oestersaus       | Vis & Zeevruchten    | Sauzen & Condimenten   |
| visbouillon      | Vis & Zeevruchten    | Bouillon & Smaakmakers |
| mozzarella       | Zuivel               | Kaas                   |
| cappuccinopoeder | Zuivel               | Koffie & Thee          |
| havermout        | Noten & Zaden        | Ontbijtgranen          |
| boekweit         | Bakproducten         | Pasta, Rijst & Noedels |
| rozijnen         | Zoetwaren            | Fruit                  |
| tofu             | Zuivel               | Peulvruchten           |
| pindakaas        | Noten & Zaden        | Zoetwaren              |
| filet americain  | Vlees                | Vleeswaren             |
| tzatziki         | Zuivel               | Sauzen & Condimenten   |
| hummus           | Peulvruchten         | Sauzen & Condimenten   |
| jam              | Sauzen & Condimenten | Zoetwaren              |
| honing           | Bakproducten         | Zoetwaren              |
| leverworst       | Vlees                | Vleeswaren             |

### 6.3 Beschikbare labels (29)

#### 🥬 VERS

| #   | Label                 | Omschrijving                  | Voorbeelden                        |
| --- | --------------------- | ----------------------------- | ---------------------------------- |
| 1   | Groente               | Verse groenten                | tomaat, ui, wortel, jalapeño       |
| 2   | Fruit                 | Vers en gedroogd fruit        | appel, banaan, rozijnen            |
| 3   | Verse kruiden         | Verse kruiden (niet gedroogd) | basilicum, peterselie, citroengras |
| 4   | Aardappelen & Knollen | Knolgewassen                  | aardappel, knolselderij, radijs    |

#### 🥩 VLEES & VIS

| #   | Label             | Omschrijving                                 | Voorbeelden                                |
| --- | ----------------- | -------------------------------------------- | ------------------------------------------ |
| 5   | Vlees             | Rauw vlees (rund, varken, lam)               | biefstuk, gehakt, varkenshaas              |
| 6   | Gevogelte         | Rauw gevogelte                               | kip, kipfilet, eend, kalkoen               |
| 7   | Vis & Zeevruchten | Vis en zeevruchten                           | zalm, garnaal, mossel, nori                |
| 8   | Vleeswaren        | Bewerkt vlees (gerookt, gedroogd, smeerbaar) | ham, bacon, salami, spek, paté, leverworst |

#### 🧊 GEKOELD

| #   | Label  | Omschrijving              | Voorbeelden                              |
| --- | ------ | ------------------------- | ---------------------------------------- |
| 9   | Zuivel | Melkproducten (geen kaas) | melk, yoghurt, room, kokosmelk           |
| 10  | Kaas   | Alle kaassoorten          | gouda, mozzarella, parmigiano, smeerkaas |
| 11  | Eieren | Eieren en delen           | ei, eidooier, eiwit                      |

#### 🍞 BROOD & ONTBIJT

| #   | Label         | Omschrijving             | Voorbeelden                    |
| --- | ------------- | ------------------------ | ------------------------------ |
| 12  | Brood & Gebak | Brood, deeg, gebak       | brood, croissant, tortilla     |
| 13  | Bakproducten  | Ingrediënten voor bakken | bloem, suiker, bakpoeder, gist |
| 14  | Ontbijtgranen | Granen voor ontbijt      | havermout, muesli              |

#### 📦 DROOG

| #   | Label                  | Omschrijving          | Voorbeelden                   |
| --- | ---------------------- | --------------------- | ----------------------------- |
| 15  | Pasta, Rijst & Noedels | Droge koolhydraten    | spaghetti, rijst, ramen, udon |
| 16  | Peulvruchten           | Bonen, linzen, erwten | kikkererwt, linzen, tofu      |
| 17  | Noten & Zaden          | Noten en zaden        | amandel, walnoot, sesamzaad   |

#### 🧂 KRUIDEN & SAUZEN

| #   | Label                  | Omschrijving                    | Voorbeelden                                      |
| --- | ---------------------- | ------------------------------- | ------------------------------------------------ |
| 18  | Kruiden & Specerijen   | Gedroogde kruiden en specerijen | kaneel, nootmuskaat, paprikapoeder               |
| 19  | Olie, Azijn & Vet      | Vetten en zuren                 | olijfolie, balsamico                             |
| 20  | Sauzen & Condimenten   | Sauzen en smaakmakers           | ketchup, sojasaus, sambal, pesto, sandwichspread |
| 21  | Bouillon & Smaakmakers | Bouillon en aroma's             | bouillon, fond, maggi                            |

#### 🍫 SNACKS & ZOET

| #   | Label     | Omschrijving                                   | Voorbeelden                                         |
| --- | --------- | ---------------------------------------------- | --------------------------------------------------- |
| 22  | Snacks    | Hartige tussendoortjes                         | chips, kroepoek, popcorn                            |
| 23  | Zoetwaren | Zoete producten, stropen, jam, zoet broodbeleg | chocolade, snoep, jam, honing, pindakaas, hagelslag |

#### 🥤 DRANKEN

| #   | Label                   | Omschrijving              | Voorbeelden                  |
| --- | ----------------------- | ------------------------- | ---------------------------- |
| 24  | Dranken                 | Frisdrank, sap, water     | cola, sinaasappelsap, tonic  |
| 25  | Wijn                    | Wijn en versterkte wijn   | rode wijn, sherry, port      |
| 26  | Bier                    | Alle biersoorten          | pils, witbier, IPA           |
| 27  | Sterke drank & Likeuren | Gedistilleerd en likeuren | rum, whisky, cointreau       |
| 28  | Koffie & Thee           | Warme dranken             | koffie, groene thee, rooibos |

#### 📍 OVERIG

| #   | Label  | Omschrijving     | Voorbeelden |
| --- | ------ | ---------------- | ----------- |
| 29  | Overig | Niet in te delen | divers      |

---

## 7. Beschrijvingen (`description`)

### Formaat (vast)

`[Korte definitie]; [gebruik/bereiding].`

### Richtlijnen

* Kort, informatief, geen marketing
* Richtlijn: < ~80 tekens (conservatief)
* Noem 1 kenmerk + 1 typische toepassing

### Voorbeelden

* Donkere saus van oesterextract; hartige smaakmaker in Aziatische keuken.
* Vette vis; veelzijdig te bereiden.
* Kruidenmix voor cajungerechten; pittig met paprika en cayenne.

---

## 8. Output-stappen (altijd uitvoeren)

1. Valideren & normaliseren

   * `aliases` bestaat altijd (minstens `[]`)
   * trim & dedupe aliases (case-insensitive)
2. Dedupliceren & consolideren

   * merge op `name` en alias-overlap
3. Splitsen waar nodig

   * vervang mix-items door eenduidige items
4. Verbeteren

   * fix pluralName, label, description-format
5. Uitbreiden (conservatief, binnen scope)

   * alleen veelvoorkomende ingrediënten passend bij de categorie
6. Sorteren

   * alfabetisch op `name` voor stabiele diffs

---

## 9. Checklijst

* [ ] Is het een ingrediënt (geen bereiding/gerecht)?
* [ ] Is `name` gangbaar Nederlands en enkelvoud?
* [ ] Is de vorm/toestand correct en niet ambigu?
* [ ] Is poeder als productnaam gebruikt waar dat gangbaar is (bv. knoflookpoeder)?
* [ ] Zijn aliases echte synoniemen/spellingvarianten (geen varianten/afgeleiden)?
* [ ] Staat het in het juiste label (uit de vaste lijst)?
* [ ] Bestaat het niet al (check ook alias-overlap)?
* [ ] Is `description` kort en in het vaste formaat?
