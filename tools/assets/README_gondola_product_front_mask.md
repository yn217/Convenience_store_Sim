# Product-front mask generator

Generates a *conditioning mask only* from the existing shelf guide JSON. It projects 9 front-facing package regions onto each of the four guide shelf rows and leaves the fixed fixture/background mask semantics intact. It does not generate art, change the fixture, or approve the output for runtime.

Example:

```powershell
python tools/assets/generate_gondola_product_front_mask.py `
  assets/review/guided_assets/shelf_general_open_r0_v1/guide.json `
  assets/review/guided_assets/shelf_general_open_r0_v1/product_front_regions_v1.png `
  assets/review/guided_assets/shelf_general_open_r0_v1/product_front_regions_v1.json
```

Output is review/conditioning data; final ImageGen output still requires visual and numeric QA.
