# Aura — Travel Companion

Your camera roll, remembered properly.

Aura reads your photo library and hands it back as **journeys**: place-named,
time-bounded trips, rebuilt automatically from where and when your photos were taken.
No albums to make, no tagging, no account. It is organised before you open it.

Everything runs on device. Photos are never uploaded, and Aura stores only asset
identifiers and derived metadata — never a copy of your images.

## Status

Milestone 1 of 6: ingest, clustering, and the journey feed. See
[`docs/SPEC.md`](docs/SPEC.md) for the full product and technical specification and the
milestone plan.

## Requirements

- iOS 26.0+
- Xcode 26+

## Layout

```
Aura.xcodeproj          app project (Xcode 16+ synchronized folders)
Aura/                   the iOS app
  App/                  entry point and root view
  Design/               theme, motion, haptics, accent extraction
  Services/             PhotoKit, geocoding, ingest orchestration
  Persistence/          SwiftData models (metadata only)
  Features/             onboarding, journeys, journey detail
Packages/AuraKit/       the platform-free core: domain types + clustering
docs/SPEC.md            product and technical specification
```

## AuraKit

The interesting logic — spatio-temporal clustering, home-base inference, chaptering —
lives in `Packages/AuraKit` and depends on nothing but Foundation. That is deliberate:
it means the algorithms that decide what a "trip" is can be tested exhaustively, in
milliseconds, on any machine, without a simulator or a photo library.

```sh
cd Packages/AuraKit && swift test
```

The suite includes a scale test that builds journeys from a synthetic 43,800-asset
library, which is what keeps first-launch ingest from quietly regressing to O(n²).

## Running the app

Open `Aura.xcodeproj`, select the `Aura` scheme, and run on a device or simulator with
photos in the library. On first launch Aura asks for photo access; limited access
("Choose Photos") is fully supported and produces a smaller but otherwise identical
experience.
