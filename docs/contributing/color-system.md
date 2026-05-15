# Console Color System

MealieSync uses a consistent color scheme across all console output to help users quickly scan results.

## Color Meanings

| Color      | Usage                                        | Example                          |
| ---------- | -------------------------------------------- | -------------------------------- |
| Cyan       | Headers, titles, item names, section dividers | `Importing Foods from: ...`      |
| Green      | Success, new values, positive outcomes        | `Created`, new field values      |
| Yellow     | Warnings, items requiring attention           | `Warning:`, matched item names   |
| Red        | Errors, conflicts, blocking issues            | `ERROR:`, `Conflict:`           |
| Dark Gray  | Old/previous values, hints, secondary info    | Old field values, `Fix:` hints   |
| White      | Neutral info, totals, standard text           | `Total processed:`, explanations |
| Gray       | Skipped items, less important info            | `Skipped`, backup paths          |
| Magenta    | Cross-references, "other" item in conflicts   | Previous import item name        |
| Dark Red   | Destructive actions (deletions)               | `DELETE:`                        |

## Operation Result Colors

| Result    | Color    |
| --------- | -------- |
| Created   | Green    |
| Updated   | Yellow   |
| Skipped   | Gray     |
| Unchanged | Gray     |
| Conflict  | Red      |
| Error     | Red      |
| Delete    | Dark Red |

## Change Display

When showing field changes, old and new values use contrasting colors:

```
fieldName   : 'old value' → 'new value'
              ↑ Dark Gray    ↑ Green
```

## Conflict Messages

```
Conflict: itemName          ← Red + Cyan
  Name 'x' matches ... 'y'  ← White + Yellow
  But 'y' was claimed by 'z' ← White + Magenta
  Fix: Remove ...           ← Dark Gray
```

## Design Principles

1. **Green = good.** New, created, success.
2. **Red = bad.** Errors, conflicts, blocks.
3. **Yellow = attention.** Warnings, changes, matches.
4. **Gray tones = secondary.** Old values, hints, skipped.
5. **Cyan = structure.** Headers, names, navigation.
6. **Magenta = reference.** "The other thing" in comparisons.
