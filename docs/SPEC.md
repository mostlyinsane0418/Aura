# Aura — Travel Companion
### Product & Technical Specification · v1.1

**Decisions locked (2026-08-08):** iOS 26 minimum · fully on-device, no cloud in v1 · no music-service
integration (audio = the user's own voice and clip audio) · "Aura" is a working name, revisit before
launch · **v1 scope = Milestones 1–3, plus the video exporter**.

---

## 0. One-paragraph pitch

You already carry every trip you've ever taken in your pocket — 40,000 photos, unsorted, unrevisited.
Aura reads that library and hands it back to you as **journeys**: place-named, time-bounded, already
curated down to the frames worth keeping. From there you can *do* something with a memory rather than
just scroll past it — narrate it in your own voice, print it as a postcard with the real postmark of the
place, develop it as a polaroid, or watch a decade of travel bloom across a 3D globe. No albums to make.
No tagging. It's organised before you open it.

**The emotional target:** the feeling of spinning a postcard rack in a gift shop in a city you love.
Tactile, browsable, collectible, slightly nostalgic. Not a file manager.

---

## 1. Why this is worth building

**The gap.** Apple Photos already does Memories, and does them well — but they're ephemeral, generic,
and non-participatory. You can't add your voice. You can't make an object out of one. You can't collect
them. Google Photos is a search engine over your life; excellent at retrieval, indifferent to meaning.
Journaling apps (Day One, Apple Journal) require you to *write*, which is why 95% of trips never get
journalled.

**Aura's wedge:** zero-effort input (it reads what's already there), high-affect output (artifacts you
want to keep and send), and a collection loop (stamps, passports, globe coverage) that makes travel
feel like it accumulates into something.

**Who it's for.** People who travel 2–8 times a year and take 200–2000 photos per trip, and who have
tried and abandoned manual organisation at least once. Secondary: people who want to *send* something —
the postcard/polaroid artifacts are the shareable surface and the organic growth channel.

**Positioning line:** *Your camera roll, remembered properly.*

---

## 2. Product principles

1. **Nothing is asked of the user before value is delivered.** First launch must show a real, correct,
   beautiful journey from their own library inside 60 seconds. Onboarding is a permission prompt and a
   progress shimmer, not a questionnaire.
2. **The photo is the interface.** Chrome is `.ultraThinMaterial` floating over imagery, never a slab
   of grey. Accent colours are extracted from the hero image, so every journey has its own palette.
3. **On-device, period.** No account, no upload, no server. This is a competitive feature, not just a
   privacy stance — it's why people will point it at 15 years of personal photos. Because we require
   iOS 26, every intelligence feature (aesthetics scoring, transcription, narrative text) runs locally
   with no network path at all.
4. **Every artifact is exportable.** A postcard that can't leave the app is a toy.
5. **Motion is continuous.** Nothing cuts. Every navigation is a `matchedGeometryEffect` transform of
   what you were already looking at.
6. **Haptics have a vocabulary.** Four distinct sensations, each meaning one thing, used sparingly
   enough that they stay meaningful.

---

## 3. Core concepts (the nouns of the app)

| Concept | Definition |
|---|---|
| **Memory** | One photo/video from the library + Aura's derived metadata (mood, aesthetics score, place). Pixels stay in Photos; Aura stores only the `localIdentifier`. |
| **Journey** | A spatio-temporally coherent cluster of Memories. "Bristol, 4–7 Aug 2026 · 214 photos". The primary unit of the app. |
| **Chapter** | A sub-cluster within a Journey — usually one day or one place. "Day 2 · Clifton Observatory". |
| **Highlight** | The 6–12 Memories Aura selects to represent a Journey. |
| **Story** | A voice recording attached to a Memory, Chapter, or Journey, with an on-device transcript. |
| **Artifact** | An exportable rendered object: Postcard, Polaroid, or Reel (video). |
| **Stamp** | A collectible earned per country/city visited. Fills the Passport. |

---

## 4. Screens & flows

### 4.1 First run
```
Splash (Aura wordmark, slow fade)
   → "Aura reads your photos to rebuild your trips. Everything stays on your phone."
   → [Choose Photos] / [Allow Full Access]        ← limited access is fully supported
   → Ingest shimmer: a live-updating world map, pins dropping as places resolve
   → First journey card slides up: "We found 12 journeys. Start with Bristol?"
```
Ingest is *progressive*: the first journey appears as soon as the most recent cluster resolves,
typically a few seconds in. Full-library backfill continues in the background.

### 4.2 Journeys (home)
Vertically scrolling feed of large journey cards. Each card: full-bleed hero image, place name in
SF Pro Display, date range and photo count in a `.secondary` caption, subtle parallax on scroll.
Sticky year headers. Pull-to-refresh triggers an incremental ingest.

Toolbar: `Journeys | Map | Globe` segmented control in a floating material capsule.

### 4.3 Journey detail
Hero image expands via `matchedGeometryEffect` into a full-width header that collapses on scroll into
a translucent title bar.

Sections, in order:
1. **Highlights** — horizontal, snapping, near-full-width cards. The default way to re-experience a trip.
2. **Story strip** — recorded voice memos with waveform + transcript excerpt; tap to play, long-press to see full transcript.
3. **Chapters** — day-by-day, each with a small map thumbnail of that day's route and a photo grid.
4. **Route map** — animated polyline drawing itself in on appear.
5. **Make something** — three large buttons: Postcard · Polaroid · Reel.

### 4.4 Memory detail
Full-screen photo, edge to edge. Swipe horizontally between memories in the journey; swipe down to
dismiss with an interactive, rubber-banding drag. Bottom material tray (drag up to expand) shows:
place, time, mood tag, "Record a story", "Make a postcard".

### 4.5 Map view
`MapKit` with clustered annotations. Pins are circular photo thumbnails, not markers. Zooming out
merges them into count bubbles; zooming into a cluster explodes it with a spring. Tapping a pin
presents the journey in a bottom sheet at medium detent.

### 4.6 Globe view
Rotatable 3D Earth (SceneKit sphere + Metal shader, NASA Blue Marble base at reduced saturation to
match the app's palette). Visited places glow. Camera flies between journeys with an eased arc. Tapping
a glow point does a fly-to and presents the journey card. Idle state: slow auto-rotation.

*Why SceneKit over MapKit's 3D mode:* MapKit gives real geography but no control over the aesthetic, and
can't render a stylised, glowing, dark-mode planet. The globe is an emotional object, not a navigation
tool — the map view already covers navigation.

### 4.7 Postcard studio
- **Front**: chosen photo, optional film/print grade, optional white border.
- **Back**: split layout — handwritten-font message on the left, stamp + postmark + address lines right.
  The postmark is generated from the real place name and date ("BRISTOL · 06 AUG 2026") in a circular
  distressed stamp. The stamp artwork is drawn from the journey's dominant colours.
- **Interaction**: drag horizontally to flip the card in 3D (`rotation3DEffect` tracking the drag).
- **Export**: `ImageRenderer` at 3× → share sheet, Photos, AirDrop, or Messages.

### 4.8 Polaroid studio
Single frame, authentic aspect ratio (square image, deep bottom chin), caption in a handwriting font,
subtle grain and vignette, slight random tilt. On creation the image "develops" — a 1.2s animated fade
from near-white to full colour, accompanied by a `.rigid` haptic at the moment it becomes legible. Shake
to speed up development (a delight easter egg, not a required interaction).

### 4.9 Reel export
A journey's highlights rendered as a shareable video: Ken-Burns pan/zoom per frame, crossfades, pacing
derived from the journey's mood profile (serene → slow, long holds; playful → quick cuts). Composed with
`AVMutableComposition` and exported to `.mov`/`.mp4` at 1080×1920 (vertical, for sharing) or 1080×1080.

**Audio in v1** is one of three, chosen by the user:
- silent,
- the original audio from any video clips included, or
- the user's own recorded Story as a narration track.

No third-party music. Beyond the licensing mess, DRM'd Apple Music tracks cannot legally or technically
be muxed into an exported file — which would break the "every artifact is exportable" principle. If
music is ever added it must be bundled, cleared-for-export audio.

### 4.10 Passport
Grid of collected stamps by country and city. Locked/greyed slots for nearby-but-unvisited places create
a light collection pull. Shows totals: countries, cities, kilometres travelled, days away.

### 4.11 Year in travel
Annual auto-generated recap: hero reel, top 10 frames by aesthetics score, dominant mood, map of the
year's routes, superlatives ("furthest from home", "longest journey"). Delivered as a notification in
mid-December.

---

## 5. The intelligence layer

### 5.1 Journey clustering
Assets carry `creationDate` and (when present) `location` from `PHAsset`. Note that Photos maintains
location in its own database separately from file EXIF, so `PHAsset.location` is the correct source.

**Algorithm — ST-DBSCAN (Birant & Kut), two independent thresholds:**
- Two photos are neighbours when `haversine ≤ ε_space` **and** `|Δt| ≤ ε_time`.
- Defaults: `ε_space = 50 km`, `ε_time = 36 h`, `minPts = 5`.
- A cluster becomes a **Journey** if its centroid is ≥ 40 km from the inferred home base.
- **Home base inference:** the densest ~0.25° cell of night-time (22:00–06:00) photo locations,
  requiring at least 20 supporting photos. Everything within 40 km of home is "everyday life" and
  excluded from Journeys (but still appears on the map).
- **No home base** (new phone, no night-time location data): fall back to duration — a cluster spanning
  ≥ 2 days is treated as travel.
- **Chapters:** re-run the same clustering inside each Journey with `ε_space = 5 km`, `ε_time = 6 h`,
  `minPts = 3`. Photos the tighter pass rejects as noise are folded into the nearest chapter in time
  rather than lost.

**Two parameter choices that are load-bearing, both found by testing rather than reasoning:**

1. *`ε_time` must exceed a night.* People shoot during the day and stop at dinner, so consecutive days
   of one trip are routinely 20+ hours apart. At 18 hours a week in Lisbon fragments into seven
   one-day "journeys". 36 hours bridges a blank day while keeping two weekend trips to the same city a
   fortnight apart firmly separate.
2. *The thresholds must be independent, not summed.* An earlier design used a single normalised metric,
   `d = km/ε_space + hours/ε_time ≤ 1`. Under it the two dimensions borrow from each other, so a trip
   that moves 25 km between towns *and* sleeps overnight spends most of both budgets and falls apart —
   which is the shape of an ordinary holiday. Separate thresholds fix this and match the published
   ST-DBSCAN formulation.

**Photos without location** (screenshots, AirDropped images, older cameras) are absorbed into the
Journey whose date range contains them, with a 12-hour grace window either side so an airport-lounge
shot before the first located photo still reads as the start of the trip. Ties between overlapping
windows go to the journey whose midpoint is nearest. Anything matching no journey is left out.

**Performance.** The neighbour query scans a time-sorted window rather than all pairs, which is what
makes first-launch ingest viable: a synthetic 43,800-asset library clusters in ~0.35s in a debug build.
This is covered by a test so it cannot silently regress to O(n²).

*Alternative considered:* PhotoKit's built-in Moments (`fetchMomentLists`) do similar grouping for free,
but they're tuned for the Photos app's own presentation, aren't tunable, and their availability has been
inconsistent across iOS versions. Recommendation: use our own clustering as the source of truth, and
optionally consult Moments as a tie-breaker signal.

### 5.2 Highlight selection
Per Journey, score each Memory:

```
score = 0.35 · aesthetics        // Vision: CalculateImageAestheticsScoresRequest → overallScore (−1…1)
      + 0.20 · faceQuality       // faces present, in focus, eyes open, large enough
      + 0.15 · subjectSalience   // Vision saliency: is there a clear subject?
      + 0.15 · moodIntensity     // strength of the assigned mood tag
      + 0.10 · rarity            // penalise near-duplicates (burst/perceptual hash)
      + 0.05 · userSignal        // favourited in Photos, edited, or shared
```
Then apply **diversity selection**: greedily take the top-scored Memory, then repeatedly take the
highest-scored Memory that is sufficiently far from those already chosen in (place, time, scene-type)
space. This prevents the classic failure mode of ten near-identical sunsets.

Vision's `isUtility` flag reliably identifies screenshots, receipts, and documents — hard-excluded from
highlights.

### 5.3 Mood / sentiment
This is *not* text sentiment analysis. It's derived from visual and contextual signals, combined into a
small, human-legible taxonomy:

| Mood | Signals |
|---|---|
| **Joyful** | smiles detected, multiple faces, high saturation, midday |
| **Serene** | landscape/water/sky scene labels, few or no faces, low visual complexity |
| **Awe** | wide vistas, mountains, monuments, high aesthetics + low face count |
| **Nostalgic** | golden-hour colour temperature, backlit, warm cast |
| **Playful** | motion blur, close crops, bursts, indoor social scenes |
| **Quiet** | night, low light, single subject, cool palette |

Signals come from Vision scene classification, face detection/expression, and image statistics
(colour temperature, saturation, complexity) — all on-device. A Journey gets a **mood profile** (a
distribution, not a single label), which drives: highlight ordering, the reel's pacing and transitions,
and the colour grade applied to postcards.

**Honesty about accuracy:** mood inference will be wrong sometimes. Mitigations: (a) never show mood as
a hard claim — it's a soft tag, tappable to change; (b) use it for *ordering and styling*, where being
wrong is cheap, not for filtering, where being wrong hides someone's photos.

### 5.4 Audio stories
- Record with `AVAudioEngine`; store `.m4a` in the app container.
- Transcribe on-device with **`SpeechAnalyzer` + `SpeechTranscriber`**, which is designed for long-form
  audio and manages its own model assets. Because iOS 26 is our floor, this is the only path — no
  `SFSpeechRecognizer` fallback to maintain.
- Transcripts make stories searchable and provide the raw material for auto-generated captions.
- Model assets download on first use; the recording UI must handle "preparing transcription" without
  blocking recording itself. Audio is captured regardless; transcription catches up.

### 5.5 Narrative text
Journey blurbs, postcard message suggestions, and chapter titles are generated by the **Foundation
Models framework** on-device LLM — no network, no cost, no data egress. Guided generation returns typed
Swift structs rather than free text to parse.

One caveat that survives the iOS 26 floor: Foundation Models requires an **Apple Intelligence-capable
device** with the feature enabled, which is a hardware and settings condition, not an OS-version one.
So a template fallback stays ("Three days in Bristol · 214 photos · mostly serene") — but it's a
small, contained path rather than a parallel implementation. Check
`SystemLanguageModel.default.availability` and degrade the copy, never the feature.

---

## 6. Architecture

```
Aura (SwiftUI, iOS 26 minimum)
│
├── App/                 entry point, scene, deep links, background tasks
├── Design/              AuraTheme — type ramp, spacing scale, motion curves,
│                        haptic vocabulary, materials, colour extraction
├── Domain/              Memory, Journey, Chapter, Place, Mood, Story, Artifact, Stamp
│                        (pure value types, no framework imports — unit-testable)
├── Features/
│   ├── Onboarding/      permission, first ingest
│   ├── Journeys/        feed + detail + chapters
│   ├── MemoryDetail/
│   ├── MapView/
│   ├── Globe/           SceneKit host + camera controller
│   ├── PostcardStudio/
│   ├── PolaroidStudio/
│   ├── Reel/           video export, built in v1 (see §10)
│   ├── Passport/
│   └── Recap/
├── Services/
│   ├── PhotoLibrary     PHAsset streaming, change observation, thumbnail cache
│   ├── Ingest           orchestrates: fetch → cluster → geocode → score → persist
│   ├── Clustering       spatio-temporal DBSCAN
│   ├── Geocoding        MKReverseGeocodingRequest + aggressive local cache (rate-limited API)
│   ├── VisionAnalysis   aesthetics, faces, saliency, scene labels, mood
│   ├── SpeechService    record + on-device transcription
│   ├── Narrative        Foundation Models wrapper with template fallback
│   └── Rendering        ImageRenderer → artifacts; AVFoundation → reel export
└── Persistence/         SwiftData: metadata only, never pixels
```

**Key architectural decisions**

- **Metadata-only persistence.** Aura stores `PHAsset.localIdentifier` plus derived metadata. It never
  copies images. Consequences: the app stays tiny, deleting a photo in Photos correctly removes it from
  Aura (via `PHPhotoLibraryChangeObserver`), and there is no second copy of the user's life to leak.
- **Ingest is a resumable pipeline.** Each stage writes its results; a killed app resumes rather than
  restarts. New assets are processed via `BGProcessingTask` on charge.
- **Vision work is batched and throttled.** Analysing 40,000 photos is a real cost. Strategy: analyse
  *recent-first*, cap concurrent requests, use thumbnails (not full-res) for scoring, and defer
  full-library backfill to charging + Wi-Fi. Target: never block the UI, never noticeably drain battery.
- **The UI layer never touches PhotoKit directly.** Everything goes through `PhotoLibraryService`, which
  is protocol-backed so previews and tests can inject fixtures.

---

## 7. Design system

**Type** — SF Pro Display for hero/title, SF Pro Text for body. Four sizes only: Hero 34/Bold,
Title 22/Semibold, Body 17/Regular, Caption 13/Medium. Generous leading. Dynamic Type supported throughout.

**Colour** — Near-black canvas (`#0B0B0D`) in dark mode, warm off-white (`#FAF8F5`) in light. Accent is
*derived per journey* from the hero image's dominant colour, clamped for contrast. No fixed brand colour
competing with the photography.

**Materials** — `.ultraThinMaterial` for floating chrome, `.regularMaterial` for sheets. Content scrolls
*under* chrome, never beside it.

**Motion** — one spring, everywhere: `.interpolatingSpring(stiffness: 220, damping: 26)`. Card→detail is
always `matchedGeometryEffect`. Dismissals are interactive and rubber-banded. Nothing linear, nothing
instant, nothing longer than 500ms except the deliberate polaroid develop (1.2s).

**Haptic vocabulary** — exactly four, each with one meaning:
| Sensation | Meaning |
|---|---|
| `.soft` impact | a card settled into place |
| selection tick | you snapped onto something (globe pin, carousel item) |
| `.rigid` impact | an artifact materialised (polaroid developed) |
| `.success` notification | export completed |

**Empty states** — never a grey box. An unpopulated globe shows a slowly rotating Earth with a single
prompt. An empty passport shows the outlined stamps you *could* collect.

---

## 8. Privacy & data handling

- Photos are read via PhotoKit and never leave the device. No image is uploaded in v1 — full stop.
- **Limited Photo Library access is a first-class path,** not a degraded one. If the user grants access
  to 40 photos, Aura builds journeys from 40 photos and offers a clear, non-nagging affordance to add more.
- Location data is used only for clustering and reverse geocoding; reverse geocoding sends coordinates
  (not images) to Apple's geocoder, which should be disclosed plainly.
- Audio recordings and transcripts stay in the app container; transcription is on-device.
- Required `Info.plist` keys: `NSPhotoLibraryUsageDescription`, `NSMicrophoneUsageDescription`,
  `NSSpeechRecognitionUsageDescription`, `NSLocationWhenInUseUsageDescription` (only if live location is added).
- Privacy nutrition label target: **"Data Not Collected."** That claim is a marketing asset; protect it.
- If cloud sync is added later it must be CloudKit private database (user's own iCloud, not our servers),
  and opt-in.

---

## 9. Risks & open technical questions

| Risk | Severity | Mitigation |
|---|---|---|
| **Photos without GPS** (screenshots, scanned film, some cameras) | High — breaks the core promise for some libraries | Time-window fallback assignment; let the user set a place for an unlocated chapter with one tap |
| **Vision analysis cost over huge libraries** | High — battery/thermal complaints kill retention | Recent-first, thumbnail-based, batched, deferred to charging; cap analysed set in v1 (e.g. trailing 3 years) with "analyse everything" as an explicit user action |
| **Mood inference feels wrong** | Medium — undermines trust | Soft tags, user-editable, used for styling not filtering |
| **Clustering produces bad journeys** (a long layover becomes its own "journey") | Medium | Merge/split affordance in journey detail; tune ε on real libraries before launch |
| **Globe performance on older devices** | Medium | Level-of-detail on the sphere; drop particles and glow below a device tier; globe is not on the critical path |
| **Foundation Models unavailable** (non-Apple-Intelligence device, or feature disabled) | Low | Template fallback; check `availability` at runtime, never a hard dependency |
| **iOS 26 floor cuts addressable audience** | Accepted | Deliberate trade for a single code path and the full on-device AI stack. Revisit only if install numbers say so |
| **First-run latency on a 40k-photo library** | High — this is the make-or-break moment | Progressive ingest: show the most recent journey first, backfill behind it. Never show a blocking spinner over an empty screen |

**Resolved**
1. **Minimum iOS: 26.** One code path, full access to Foundation Models and SpeechAnalyzer. Accepted
   audience cost.
2. **Device-only.** No cloud in v1. Consequences to accept: no cross-device sync, no shareable web
   links (sharing is share-sheet/AirDrop/Messages only), and journeys are lost if the phone is lost
   without an encrypted backup. If sync is ever added it must be CloudKit *private* database, opt-in.
3. **Audio & video only in v1.** Reels export with either silence, the original clip audio, or the
   user's own recorded story as the narration track. Bundled royalty-free beds are a v1.1 nicety;
   Apple Music integration is deferred indefinitely (its DRM makes exported video impossible anyway,
   which is a good reason to never do it).
4. **v1 = Milestones 1–3.** See §10.
5. **Name.** "Aura" is the working name. Before any launch investment, clear it against the App Store
   (Aura Frames, Aura Health, Aura Photos all exist) and trademark registers.

**Still open (not blocking)**
- Should Journeys be user-editable (merge/split/rename) in v1, or is that v1.1? I'd include *rename* in
  v1 and defer merge/split — renaming is cheap and covers the most common "that's wrong" reaction.
- How far back does v1 analyse by default? Proposal: trailing 3 years automatically, with an explicit
  "analyse my whole library" action.

---

## 10. Milestones

Each milestone is a shippable slice, roughly one focused session of work.

| # | Milestone | Contents | Proves |
|---|---|---|---|
| 1 | **It's already organised** | Ingest, clustering, geocoding, journey feed, journey detail | The core promise |
| 2 | **The good ones** | Vision scoring, highlights, diversity selection, chapters, route map | Curation quality |
| 3 | **Make something** | Postcard studio, polaroid studio, video exporter, export/share | The shareable hook |
| 4 | **Your voice** | Audio recording, on-device transcription, story strip, search | Depth & retention |
| 5 | **How it felt** | Mood taxonomy, mood-driven ordering and grading, narrative text | Differentiation |
| 6 | **The world** | 3D globe, mood-scored reel pacing, passport, year-in-travel recap | The demo moment |

### v1 scope — decided

**Milestones 1–3 ship as v1.** Reasoning: 1 proves the promise, 2 makes it *good*, and 3 gives people
something to make and send — which is both the retention hook and the only organic growth channel a
device-only app has. That's a complete, coherent product: *your trips, already organised, with something
beautiful to make out of them.*

Everything after is additive rather than load-bearing:
- **v1.1 — Milestones 4–5.** Voice stories and mood. Depth for people who already like the app.
- **v1.2 — Milestone 6.** Globe, reel, passport, year-in-travel. The demo moment and the seasonal
  re-engagement hook (a December recap notification is the single best retention lever here).

One deliberate exception: **build the reel exporter in v1** even though the animated gallery is a
Milestone 6 feature. Video export shares almost all its plumbing with postcard/polaroid rendering, and
a shareable video is worth far more distribution than a static image. It's cheap now and expensive to
retrofit.

---

## 11. What would make this succeed or fail

**It succeeds if** the first launch produces a journey the user recognises as *right* — correct place
name, correct dates, and a set of highlights they'd have picked themselves. That single moment carries
the entire product. Everything downstream is craft.

**It fails if** the first launch is a spinner over an empty screen, or the first journey is called
"Unknown Location" and contains 40 screenshots. Both are preventable, and both are engineering problems
in the ingest pipeline — which is why Milestone 1 deserves disproportionate polish.

---

## 12. Build status

**Milestone 1 is implemented.** Ingest, clustering, chaptering, persistence, the design system, the
journey feed, journey detail and the memory viewer all exist.

The clustering core lives in `Packages/AuraKit` and depends on Foundation alone, so it can be tested
exhaustively without a simulator or a photo library — 41 tests, including the 43,800-asset scale test.
That split is the reason the two clustering parameter bugs in §5.1 were found before any UI existed
rather than after shipping.

**Not yet verified:** the SwiftUI layer has never been compiled or run. It was written against the
iOS 26 SDK but not built, so expect first-build friction on a Mac — this is the honest checkpoint
before Milestone 2.

Next, in order:
1. Build and run Milestone 1 on a device with a real library.
2. Tune `ε_space`, `ε_time` and the home-base radius against that library. The synthetic tests prove
   the algorithm behaves as specified; only real photos prove the *defaults* are right.
3. Milestone 2 (Vision scoring, highlights, route map), then Milestone 3 (postcard, polaroid, video).
