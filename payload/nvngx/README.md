# nvngx runtime - not in git

GitHub refuses files over 100 MB, and `nvngx_dlssnr.dll` alone is ~158 MB, so the
NVIDIA runtime lives in the release archive instead:

**`nvngx-dlss5-runtime.zip`** on the [releases page](../../releases/latest).

`INSTALL.bat` downloads and unpacks it here automatically. If you would rather do it
by hand, download that zip and extract it **into this folder** - you should end up with
`payload\nvngx\nvngx_dlssnr.dll` and friends, then run `INSTALL.bat`.

Expected contents:

| File | Version | Size |
| --- | --- | --- |
| `nvngx_dlss.dll` | 310.9.1.0 | 59 MB |
| `nvngx_dlssd.dll` | 310.9.1.0 | 48 MB |
| `nvngx_dlssg.dll` | 310.9.1.0 | 7.5 MB |
| `nvngx_dlssnr.dll` | 310.8.SF.0 | 158 MB |
| `sl.*.dll` (11 files) | 2.14.1.0 | 5.5 MB |

The release archive `nvngx-dlss5-runtime.zip` is **170 MB** (178898810 bytes) and its SHA256 is:

```
dcf553c198ff1e27755be6997eba2c3fd912f96a7e38913f38e198bdf607c8b7
```

It is also in the release notes. `INSTALL.bat` prints the hash of what it downloaded, so you can
compare before anything is copied into your LS folder.

`nvngx_dlssnr.dll` is the neural-rendering runtime: the `SF` build is the community
patched one that works on RTX 20/30/40. RTX 50 cards can use NVIDIA's own build
instead - drop it in here under the same name before installing.

The installer prints the SHA256 of the archive it downloads so you can compare it
against the one in the release notes.
