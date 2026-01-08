# MealieSync Console Color Guide

## Color Meanings

| Color | Usage | Example |
|-------|-------|---------|
| **Cyan** | Headers, titles, item names, section dividers | `Importing Foods from: ...` |
| **Green** | Success, new values, positive outcomes | `Created`, `Updated`, new field values |
| **Yellow** | Warnings, items requiring attention, matched items | `Warning:`, existing item names in conflicts |
| **Red** | Errors, conflicts, blocking issues | `ERROR:`, `Conflict:` |
| **DarkGray** | Old/previous values, hints, secondary info | Old field values, `Fix:` suggestions |
| **White** | Neutral info, totals, standard text | `Total processed:`, explanatory text |
| **Gray** | Skipped items, verbose info, less important | `Skipped`, backup paths |
| **Magenta** | Cross-references, "other" item in conflict | Previous import item name |
| **DarkRed** | Destructive actions (delete) | `DELETE:` |

## Operation Results

| Result | Color |
|--------|-------|
| Created | Green |
| Updated | Yellow |
| Skipped | Gray |
| Unchanged | Gray |
| Conflict | Red |
| Error | Red |
| Delete | DarkRed |

## Change Display

```
fieldName   : 'old value' → 'new value'
              ↑ DarkGray     ↑ Green
```

## Conflict Messages

```
Conflict: itemName          ← Red + Cyan
  Name 'x' matches ... 'y'  ← White + Yellow
  But 'y' was claimed by 'z' ← White + Magenta  
  Fix: Remove ...           ← DarkGray
```

## Design Principles

1. **Green = good** - New, created, success
2. **Red = bad** - Errors, conflicts, blocks
3. **Yellow = attention** - Warnings, changes, matches
4. **Gray tones = secondary** - Old values, hints, skipped
5. **Cyan = structure** - Headers, names, navigation
6. **Magenta = reference** - "The other thing" in comparisons
