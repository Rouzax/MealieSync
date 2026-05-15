# Troubleshooting

## Execution Policy Error

If PowerShell blocks the scripts from running:

```powershell
# Unblock downloaded files
Get-ChildItem -Recurse | Unblock-File

# Or set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Connection Errors

Run the diagnostic tool:

```powershell
.\Tools\Test-MealieConnection.ps1 -Detailed
```

Common causes:

- **Wrong port number in URL.** Check the port Mealie is actually running on.
- **Trailing slash in URL.** Remove it (use `http://server:9000`, not `http://server:9000/`).
- **Expired or invalid API token.** Generate a new one in Mealie under Profile > Manage Your API Tokens.
- **Firewall blocking connection.** Ensure the Mealie port is accessible from your machine.

## Items Not Updating

By default, Import skips existing items. Add `-UpdateExisting` to update them:

```powershell
.\Invoke-MealieSync.ps1 -Action Import -Type Foods -JsonPath .\Foods.json -UpdateExisting
```

This also applies to Mirror, which always updates existing items as part of its import phase.

## Special Characters Garbled

Ensure JSON files are saved as **UTF-8 without BOM**. MealieSync handles UTF-8 encoding for all API requests, but the source files must also be UTF-8.

Common symptoms: accented characters (e.g., `jalapeño`, `maïs`) appear as garbled text in Mealie after import.

## Import Validation Error

If you see "Missing type wrapper" or "Type mismatch":

- Ensure your JSON has the wrapper format with `$schema`, `$type`, and `$version` fields. See [JSON Format](reference/json-format.md).
- Check that `$type` matches what you are importing (e.g., `"Foods"` when using `-Type Foods`).
- If you have legacy files (raw JSON arrays), convert them with `Tools/Convert-MealieSyncJson.ps1`.

## Conflicts Blocking Import

If you see "Import aborted: N conflict(s) found", your data files contain duplicate items. See [Conflict Detection](usage/importing.md#pre-import-conflict-detection) for how to interpret and fix conflicts.

Common fixes:

- **Same item in multiple files.** Remove the duplicate from one file.
- **Alias conflicts with another item's name.** Remove the alias or rename one of the items.
- **Within-file duplicates.** Search for the item name in the file and remove the extra entry.
