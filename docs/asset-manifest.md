# Asset Manifest

## Night Market

### Reused from Hiraeth010/neon-district

Source: [Hiraeth010/neon-district](https://github.com/Hiraeth010/neon-district), pinned commit 6bea17fd7ad6467664382e14887fc89d1886448a. Repository license and third-party notices are retained in [art/source/third_party/neon-district](../art/source/third_party/neon-district/). The upstream Blender city includes user-reference campaign art; those images are excluded from our district source and exports.

| Local asset | Upstream source | SHA-256 |
|---|---|---|
| [Editable market slice](../art/source/environment/night_market/neon_market_district.blend) | blender/neon-district-city.blend, extracted from VESPER / street composition | 078df2b2c6d40b74fcd7b6a0a7a52bcc45bf4444372b4d1bc0a56ac297a9827e |
| [300 m district GLB](../game/assets/environment/night_market/neon_market_district.glb) | 01 CITY, 02 NEON, 07 STREET FRONTS, 09 AUTHORED BLOCKS; user-reference image panels omitted | b25b4c471639c068d8625111a4b56252d25839092ca727086b4245e22c455d52 |
| [Market kiosk GLB](../game/assets/environment/night_market/neon_market_kiosk.glb) | public/assets/kiosk.glb | b1ff6db41da20896428d38fa99a0dbe82480e45a249ed44d2e24a2add4111de7 |
| [Relay GLB](../game/assets/environment/night_market/neon_district_relay.glb) | public/assets/relay.glb | 3e950165945231204dfb45c714ad7ef1bfce8a30862ae2ddab14dff3b177917c |
| [Energy crate GLB](../game/assets/environment/night_market/neon_district_energy_crate.glb) | public/assets/crate.glb | cf166a0d037712c68682de8e11471a00a47d7d4140724e41be151b08e0bb4355 |

The district extraction script is [extract_neon_market_slice.py](../tools/blender/extract_neon_market_slice.py). It translates the selected 300 m × 300 m source crop to the local origin, converts the authored VoxelTint attribute to a GLTF-compatible Principled material, and excludes campaign-image textures. It was run using Blender 5.2.3.

### Main Agent authored kit (ASSET-08 in progress)

Editable source and module exports are under art/source/environment/night_market/night_market_modular_kit.blend, tools/blender/build_night_market_kit.py, and game/assets/environment/night_market/night_market_*.glb. These remain under review; see [ASSET-08 report](reports/ASSET-08.md). They are not claimed as accepted.
