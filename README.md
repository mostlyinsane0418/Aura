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

### Testing in the Simulator

The Simulator's stock photos carry **no GPS metadata**, so Aura correctly finds no
journeys in them and there is nothing to look at. Generate a library that does have
coordinates:

```sh
python3 -m pip install piexif Pillow
python3 Tools/generate_sample_library.py --out ~/aura-sample-library
xcrun simctl addmedia booted ~/aura-sample-library/*.jpg
```

That produces a Bristol home base, three trips that should each become one journey
(Tokyo including an 80km day trip to Hakone, Lisbon with Sintra and Cascais,
Edinburgh), a day trip to Bath that should deliberately *not* become a journey, and a
handful of location-less "screenshots" that should be absorbed into the trip they
happened during. Every image is labelled with its place and date, so a mis-grouping is
visible at a glance.

## Diagnosing an empty feed

An empty feed has several very different causes that look identical from outside, so
the app shows its working: tap **Why is this empty?** on the empty state for photo
counts, how many have coordinates, the inferred home base, and the accept/reject reason
for every cluster.

The same analysis runs from the command line over any folder of images, with no phone
and no app build involved:

```sh
python3 Tools/probe_library.py ~/aura-sample-library > library.json
(cd Packages/AuraKit && swift run aura-probe < ../../library.json)
```
