# Credits and third-party notices

This repository is a **configuration preset plus an installer**. Almost none of the software in it
was written here. Everything below belongs to its author and keeps its own licence.

## Bundled in `payload/`

| File | Author / project | Licence | Source |
| --- | --- | --- | --- |
| `dxgi.dll` (ReShade 6.8.0.2155, full add-on support) | crosire · [ReShade](https://reshade.me) | ReShade's own licence — free to use and redistribute; see [Licenses.txt](https://github.com/crosire/reshade/blob/main/LICENSE.md) | [reshade.me](https://reshade.me) |
| `renodx-dlss.addon64` (build 2026-09-17) | ShortFuse · [RenoDX](https://github.com/clshortfuse/renodx) | RenoDX licence — see the project repository | Distributed through the [RenoDX Discord](https://discord.com/channels/1408098019194310818/1543975158937821315) |
| `Lossless.dll` (LosslessProxy v0.3.0) | FrankBarretta · [LosslessProxy](https://github.com/FrankBarretta/LosslessProxy) | MIT | GitHub releases |
| `addons\LSP-Windowed\` (v0.3.0) | FrankBarretta · [LSP-Windowed](https://github.com/FrankBarretta/LSP-Windowed) | MIT | GitHub releases |

## Shipped in the release archive, not in git

| File | Author / project | Licence |
| --- | --- | --- |
| `nvngx_dlss.dll`, `nvngx_dlssd.dll`, `nvngx_dlssg.dll` (310.9.1.0) | NVIDIA — DLSS Super Resolution / Ray Reconstruction / Frame Generation | NVIDIA proprietary, redistributed for convenience |
| `nvngx_dlssnr.dll` (310.8.SF.0) | NVIDIA, community-patched (`SF`) build for the Neural Rendering runtime | NVIDIA proprietary |
| `sl.*.dll` (Streamline 2.14.1.0) | NVIDIA | NVIDIA proprietary |

`nvngx_dlssnr.dll` is the piece that makes DLSS 5 Neural Rendering run on RTX 20/30/40. The `SF`
build is a community patch, not an NVIDIA release. NVIDIA's own build is what RTX 50 cards use.

## Not bundled, but you need it

| Thing | Author | Note |
| --- | --- | --- |
| **Lossless Scaling** | THS · [Steam](https://store.steampowered.com/app/993090/) | The capture and present layer this whole setup plugs into. Paid software; not included here |
| **RHI** | RankFTW · [RHI](https://github.com/RankFTW/RHI) | The installer most people use to put ReShade and the DLSS files in place. You do not need it with this repo — but it is the better tool if you want to manage components yourself |

## Documentation

The [dlss5-anywhere](https://github.com/Won-Cafe/dlss5-anywhere) README by **Won-Cafe** is the
clearest explanation of how LS, ReShade, the add-on and the NR runtime fit together. The settings,
the `-Scale` behaviour and several of the gotchas documented here were learned from it.

## Trademarks

DLSS, GeForce, RTX and NVIDIA are trademarks of NVIDIA Corporation. Lossless Scaling belongs to
THS. ReShade belongs to crosire. RenoDX belongs to ShortFuse. LosslessProxy and LSP-Windowed belong
to FrankBarretta. None of these projects are affiliated with, endorse, or support this repository.

## On redistribution

The third-party binaries here are redistributed so that installation is a single download, and
because every one of them is already distributed publicly by its author. If you are one of the
authors above and you would rather this repository linked to your releases instead of bundling
them, open an issue and it will be changed.

`LosslessProxy` and `LSP-Windowed` are unofficial. FrankBarretta notes that they may conflict with
the Lossless Scaling terms of service.
