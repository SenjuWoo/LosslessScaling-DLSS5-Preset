# Changelog

## 1.0.1 - 2026-11-25

- `INSTALL.bat -DryRun` now changes nothing and exits 0. Before, it created the `addons\LSP-Windowed`
  folder in the Lossless Scaling folder, printed "written" for INI keys it never wrote, then ran the
  install verification against the untouched folder and exited 1 with every file reported missing.
- The CI test covers the dry run: folder snapshot before and after, no backup or manifest, exit 0.
- README: cover image, CI badge, terminal shots from real runs, a section on the HW acceleration
  key the launcher sets (the old link pointed at a missing heading), the full option list for the
  three launchers, the runtime archive size corrected to 170 MB (about 275 MB unpacked), and a note
  that re-running the installer writes the shipped Scale/Style values back.
- README images live in `docs/presentation/` and are left out of the Download ZIP.
- The NVIDIA runtime archive is unchanged (same file, same SHA256) and is attached to this release
  again, because the installer downloads it from the latest release.

## 1.0.0 - 2026-09-20

- First release: LosslessProxy, ReShade 6.8.0 with add-on support, the RenoDX DLSS add-on, the
  preconfigured `ReShade.ini`, and `INSTALL.bat` / `UNINSTALL.bat` / `LAUNCH-LosslessScaling.bat`.
  The NVIDIA runtime ships as `nvngx-dlss5-runtime.zip` on the release page.
