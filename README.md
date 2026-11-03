# My OpenCore Configurator 1.0.8 validator workaround

I wrote and tested this workaround for **OpenCore Configurator 2.78.2.0** while editing an **OpenCore 1.0.8 Release** configuration. I reproduced false `No schema for HideVerbose` errors because the published Development validator predates `UEFI → Drivers → HideVerbose`. I reported the problem in [mackie100/OCClocalizations#412](https://github.com/mackie100/OCClocalizations/issues/412).

## Use

1. Download [`fix-opencore-configurator-1.0.8.command`](fix-opencore-configurator-1.0.8.command) to the Mac. Run it as your normal user by double-clicking it or with `bash fix-opencore-configurator-1.0.8.command`.
2. The script activates OpenCore Configurator, waits for its validator cache, then installs the official OpenCore 1.0.8 Release `ocvalidate` into the Development cache. It preserves the cache archive's timestamp and selects the Development profile.
3. Open `config.plist` in Configurator to trigger its **automatic** validation. The title should show `1.0.8 Development Configuration`, while the validator itself reports compatibility with OpenCore 1.0.8.

I made the script download the [official OpenCore 1.0.8 Release archive](https://github.com/acidanthera/OpenCorePkg/releases/tag/1.0.8) and verify the validator's SHA-256 before changing anything. If GitHub downloads are unavailable, pass a local `OpenCore-1.0.8-RELEASE.zip` as its argument. The script checks the installed Configurator version and stops without changing its cache if the app is not version 2.78.2.0. It does not read or modify EFI or `config.plist`.

**Scope:** I confirmed that the main window's automatic validator uses the corrected cache. **Tools → Advanced OpenCore Validator** downloads the outdated resource again when run and can restore the false errors. Re-run my script after using that tool or reinstalling Configurator. I still need the Configurator developer to provide updated resources and a 1.0.8 Release profile for a permanent fix.

## Undo

The script backs up the existing validator cache and profile under `~/Library/Application Support/OpenCore Configurator Validator Fix/backups/`. Run `bash fix-opencore-configurator-1.0.8.command --restore` to restore the most recent backup.
