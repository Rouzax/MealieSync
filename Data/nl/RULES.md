# Mealie Ingrediënten Database - Regels en Richtlijnen

## Mealie Terminologie

| Term       | Gekoppeld aan | Voorbeeld                    |
| ---------- | ------------- | ---------------------------- |
| **Labels** | Ingrediënten  | "Groente", "Vlees", "Zuivel" |
| **Tags**   | Recepten      | "Vegetarisch", "Snel klaar"  |

Dit document gaat over **Labels** voor ingrediënten.

---

## 1. Wat is een ingrediënt?

### Wel opnemen
- Basis grondstoffen (groenten, fruit, vlees, kruiden, etc.)
- Halffabrikaten die als ingrediënt worden gebruikt (bloem, pasta, bouillon)
- Sauzen en condimenten die aan gerechten worden toegevoegd
- **Voorbewerkte ingrediënten** - kant-en-klaar gekocht als basis voor gerechten:
  - gerookte makreel, kipschnitzel, shoarmareepjes, geroosterde amandelen

### Niet opnemen
- **Bereidingen/eindproducten** - gerechten die je zelf maakt:
  - aardappelpuree, kroket, overnight oats, soufflé, beslag
- **Kant-en-klare gerechten**: parfait, sorbet, petit-four
- **Merknamen**: Campina roomkaas, Kiri, Monchou, Grape-Nuts, Spa Blauw
- **Te generieke termen**: sap, deeg
- **Obscure/onbekende items**: haramaki, sampan saus, ravioles

---

## 2. Naamgeving

### Primaire naam
- Altijd de **gangbare Nederlandse naam**
- Altijd **enkelvoud** (aardappel, niet aardappels) - het `pluralName` veld is voor meervouden
- Geen merknamen als primaire naam
- Geen Engelse namen tenzij internationaal ingeburgerd (IPA, red velvet)

### Meervoud (pluralName)
- Gebruik de gangbare Nederlandse meervoudsvorm

### Voorbeelden
| ❌ Fout                   | ✅ Goed          |
| ------------------------ | --------------- |
| maple syrup              | ahornsiroop     |
| sirop de Liège           | Luikse stroop   |
| blue curaçao             | blauwe curaçao  |
| thousand island dressing | cocktailsaus    |
| nutritional yeast        | edelgistvlokken |
| spa blauw                | mineraalwater   |
| cottage cheese           | hüttenkäse      |
| plantain                 | bakbanaan       |

---

## 3. Aliassen

### Wat is een alias?
Een alias is een **alternatieve naam voor exact hetzelfde ingrediënt**.

### Aliassen en meervouden

**Regel**: Het meervoud van `name` hoort in `pluralName`, niet in `aliases`.

Aliassen mogen wél in meervoudsvorm voorkomen — inclusief zowel enkelvoud als meervoud van dezelfde alias.

**Voorbeeld**:
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

| Veld         | Waarde          | Toelichting                          |
| ------------ | --------------- | ------------------------------------ |
| `name`       | aardappel       | Primaire naam (enkelvoud)            |
| `pluralName` | aardappelen     | Meervoud van `name`                  |
| `aliases`    | pieper, piepers | Synoniem + meervoud van dat synoniem |

**Dus niet**:
```json
"aliases": [{ "name": "aardappelen" }]  ❌
```

### Niet als alias
- **Variëteiten**: Elstar (appel), conference (peer), jonagold
- **Afgeleide producten**: citroensap, limoenrasp, granaatappelpitten
- **Andere producten**: paksoi ≠ chinese kool, krenten ≠ rozijnen
- **Bereidingen**: espresso ≠ koffie, pulled pork ≠ varkensschouder
- **Varianten**: buffelmozzarella, braadworst, chipolata

### Wel als alias
- **Synoniemen**: "pieper"/"piepers" voor aardappel, "kroot" voor biet
- **Vertalingen**: "maizena" voor maïszetmeel, "tarragon" voor dragon
- **Alternatieve spellingen**: "balsamico" voor aceto balsamico
- **Spellingen zonder diakritische tekens**: "mais" voor maïs, "jalapeno" voor jalapeño
- **Spellingen met spaties**: "kippenbouillon blokje" voor kippenbouillonblokje, "pinda kaas" voor pindakaas

### Regel
Als je twijfelt: **maak er een apart ingrediënt van**.

---

## 4. Splitsen van ingrediënten

### Regel
**Altijd splitsen** bij:
- Verschillende delen van hetzelfde dier/plant
- Vers vs gedroogd
- Heel vs gemalen
- Rasp/sap/schil van fruit

Geen uitzonderingen. Dit houdt het simpel en voorspelbaar.

### Zaad / Gemalen / Gedroogd / Vers

| Situatie                                     | Regel     | Voorbeeld                          |
| -------------------------------------------- | --------- | ---------------------------------- |
| Ander plantdeel (blad vs zaad, knol vs blad) | **Apart** | koriander + korianderzaad          |
| Vers vs gedroogd                             | **Apart** | gember + gemberpoeder              |
| Heel vs gemalen                              | **Apart** | nootmuskaat + gemalen nootmuskaat  |
| Rasp/sap/schil van fruit                     | **Apart** | citroen + citroenrasp + citroensap |

### Voorbeelden

**Kruiden & specerijen:**
- koriander ↔ korianderzaad
- venkel ↔ venkelzaad
- gember ↔ gemberpoeder
- knoflook ↔ knoflookpoeder
- ui ↔ uienpoeder
- paprika ↔ paprikapoeder
- kaneel ↔ kaneelstokje
- nootmuskaat ↔ gemalen nootmuskaat
- zwarte peper ↔ zwarte peperkorrels
- witte peper ↔ witte peperkorrels
- kardemom ↔ gemalen kardemom
- kruidnagel ↔ gemalen kruidnagel

**Fruit:**
- citroen ↔ citroenrasp ↔ citroensap
- limoen ↔ limoenrasp ↔ limoensap
- sinaasappel ↔ sinaasappelrasp ↔ sinaasappelsap

**Gevogelte:**
- kip → kip, kipfilet, kippendij, kippenpoot, kippenvleugel, kipgehakt

**Vlees:**
- varkensvlees → varkensvlees, varkenshaas, varkensfilet, varkensschouder
- gehakt → gehakt, rundergehakt, varkensgehakt, half-om-half gehakt

**Eieren:**
- ei, eidooier, eiwit (apart, niet als aliassen)

**Kaas:**
- mozzarella en buffelmozzarella apart
- jonge kaas, belegen kaas, oude kaas apart

---

## 5. Labels

### Veelgemaakte fouten

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

### Beschikbare labels (29)

---

#### 🥬 VERS

| #   | Label                     | Omschrijving                  | Voorbeelden                        |
| --- | ------------------------- | ----------------------------- | ---------------------------------- |
| 1   | **Groente**               | Verse groenten                | tomaat, ui, wortel, jalapeño       |
| 2   | **Fruit**                 | Vers en gedroogd fruit        | appel, banaan, rozijnen            |
| 3   | **Verse kruiden**         | Verse kruiden (niet gedroogd) | basilicum, peterselie, citroengras |
| 4   | **Aardappelen & Knollen** | Knolgewassen                  | aardappel, knolselderij, radijs    |

---

#### 🥩 VLEES & VIS

| #   | Label                 | Omschrijving                                 | Voorbeelden                                |
| --- | --------------------- | -------------------------------------------- | ------------------------------------------ |
| 5   | **Vlees**             | Rauw vlees (rund, varken, lam)               | biefstuk, gehakt, varkenshaas              |
| 6   | **Gevogelte**         | Rauw gevogelte                               | kip, kipfilet, eend, kalkoen               |
| 7   | **Vis & Zeevruchten** | Verse vis en schaaldieren                    | zalm, garnaal, mossel, nori                |
| 8   | **Vleeswaren**        | Bewerkt vlees (gerookt, gedroogd, smeerbaar) | ham, bacon, salami, spek, paté, leverworst |

---

#### 🧊 GEKOELD

| #   | Label      | Omschrijving              | Voorbeelden                              |
| --- | ---------- | ------------------------- | ---------------------------------------- |
| 9   | **Zuivel** | Melkproducten (geen kaas) | melk, yoghurt, room, kokosmelk           |
| 10  | **Kaas**   | Alle kaassoorten          | gouda, mozzarella, parmigiano, smeerkaas |
| 11  | **Eieren** | Eieren en delen           | ei, eidooier, eiwit                      |

---

#### 🍞 BROOD & ONTBIJT

| #   | Label             | Omschrijving             | Voorbeelden                    |
| --- | ----------------- | ------------------------ | ------------------------------ |
| 12  | **Brood & Gebak** | Brood, deeg, gebak       | brood, croissant, tortilla     |
| 13  | **Bakproducten**  | Ingrediënten voor bakken | bloem, suiker, bakpoeder, gist |
| 14  | **Ontbijtgranen** | Granen voor ontbijt      | havermout, muesli              |

---

#### 📦 DROOG

| #   | Label                      | Omschrijving          | Voorbeelden                   |
| --- | -------------------------- | --------------------- | ----------------------------- |
| 15  | **Pasta, Rijst & Noedels** | Droge koolhydraten    | spaghetti, rijst, ramen, udon |
| 16  | **Peulvruchten**           | Bonen, linzen, erwten | kikkererwt, linzen, tofu      |
| 17  | **Noten & Zaden**          | Noten en zaden        | amandel, walnoot, sesamzaad   |

---

#### 🧂 KRUIDEN & SAUZEN

| #   | Label                      | Omschrijving                    | Voorbeelden                                      |
| --- | -------------------------- | ------------------------------- | ------------------------------------------------ |
| 18  | **Kruiden & Specerijen**   | Gedroogde kruiden en specerijen | paprikapoeder, kaneel, laos                      |
| 19  | **Olie, Azijn & Vet**      | Vetten en zuren                 | olijfolie, balsamico                             |
| 20  | **Sauzen & Condimenten**   | Sauzen en smaakmakers           | ketchup, sojasaus, sambal, pesto, sandwichspread |
| 21  | **Bouillon & Smaakmakers** | Bouillon en aroma's             | bouillon, fond, maggi                            |

---

#### 🍫 SNACKS & ZOET

| #   | Label         | Omschrijving                                   | Voorbeelden                                         |
| --- | ------------- | ---------------------------------------------- | --------------------------------------------------- |
| 22  | **Snacks**    | Hartige tussendoortjes                         | chips, kroepoek, popcorn                            |
| 23  | **Zoetwaren** | Zoete producten, stropen, jam, zoet broodbeleg | chocolade, snoep, jam, honing, pindakaas, hagelslag |

---

#### 🥤 DRANKEN

| #   | Label                       | Omschrijving              | Voorbeelden                  |
| --- | --------------------------- | ------------------------- | ---------------------------- |
| 24  | **Dranken**                 | Frisdrank, sap, water     | cola, sinaasappelsap, tonic  |
| 25  | **Wijn**                    | Wijn en versterkte wijn   | rode wijn, sherry, port      |
| 26  | **Bier**                    | Alle biersoorten          | pils, witbier, IPA           |
| 27  | **Sterke drank & Likeuren** | Gedistilleerd en likeuren | rum, whisky, cointreau       |
| 28  | **Koffie & Thee**           | Warme dranken             | koffie, groene thee, rooibos |

---

#### 📍 OVERIG

| #   | Label      | Omschrijving     | Voorbeelden    |
| --- | ---------- | ---------------- | -------------- |
| 29  | **Overig** | Niet in te delen | havermoutvlees |

---

### Labelprincipes

1. **Label op wat het IS**, niet waar het vandaan komt
   - visbouillon → Bouillon (niet Vis)
   - oestersaus → Sauzen (niet Vis)

2. **Kaas altijd apart van Zuivel**
   - mozzarella, parmigiano, smeerkaas → Kaas
   - yoghurt, kokosmelk → Zuivel

3. **Zoetwaren = zoete producten inclusief broodbeleg**
   - jam, honing, stropen, hagelslag, pindakaas → Zoetwaren
   - chocolade, snoep → Zoetwaren

4. **Vleeswaren = bewerkt vlees (ook smeerbaar)**
   - ham, bacon, salami → Vleeswaren
   - paté, leverworst, filet americain → Vleeswaren

---

## 6. Beschrijvingen

### Formaat
`[Korte definitie]; [gebruik/bereiding].`

### Voorbeelden
- "Donkere saus van oesterextract; hartige smaakmaker in Chinese keuken."
- "Vette vis; roze vlees, veelzijdig te bereiden."
- "Kruidenmix voor cajungerechten; pittig met paprika en cayenne."

### Richtlijnen
- Houd beschrijvingen kort en informatief
- Vermeld kenmerkende eigenschappen
- Noem typisch gebruik waar relevant

---

## 7. Samenvatting checklijst

Voordat je een ingrediënt toevoegt, check:

- [ ] Is het een ingrediënt (geen bereiding/gerecht)?
- [ ] Is de primaire naam Nederlands?
- [ ] Zijn aliassen echte synoniemen (geen varianten, meervoud van `name` hoort in `pluralName`)?
- [ ] Staat het in het juiste label?
- [ ] Bestaat het niet al (check ook aliassen)?
- [ ] Is het geen merknaam?
- [ ] Is vers/gedroogd of heel/gemalen correct gesplitst?
