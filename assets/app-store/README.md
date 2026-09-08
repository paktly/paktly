# Paktly App Store Media

The upload-ready PNGs are included in this repository. On your Mac, run `git pull --ff-only` from the Paktly repository, then `open assets/app-store/iphone-6.5` for the 6.5-inch upload slot.

Upload the eight numbered PNG files in `iphone-6.9/` to the iPhone 6.9-inch screenshot slot in App Store Connect, in filename order. They are RGB `1290 × 2796` PNGs with no alpha channel.

The matching `iphone-6.5/` files are RGB `1284 × 2778` PNGs for the optional 6.5-inch slot. Apple can scale the 6.9-inch set for smaller iPhones, so use the 6.5-inch set only when you want explicit control over that presentation.

The sequence tells a broad shared-planning story rather than positioning Paktly as travel-only:

1. Home and shared financial position
2. Multiple types of shared plans
3. The global Add center
4. Receipt scanning
5. Flexible plan types
6. Invitations
7. Multiple currencies
8. Balances

The real application captures remain unaltered inside the device frames. Editable SVG compositions are in `source/`. `source/paktly-background.png` is the generated Paktly backdrop used at low opacity.

Regenerate from the repository root:

```bash
assets/app-store/generate-screenshots.sh
```

Requirements: Google Chrome and FFmpeg. Override Chrome with `CHROME=/path/to/chrome` when necessary.

Regeneration additionally requires the original `screenshots/` captures, which are not included in this commit. You do not need them to upload the prepared PNGs. Review the screenshots against your submitted app build before publication.
