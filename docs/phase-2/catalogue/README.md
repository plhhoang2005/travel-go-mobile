# Catalogue readiness — 12 destinations

Checked 2026-10-13. Source preparation only; not published to Supabase or wired
into the Decision Engine. Canonical IDs match the twelve approved destination
IDs in its existing data. No ranking, backend repo, Owner asset or app change.

Read-only baseline inspection: Decision Engine has 23 destination entries;
`pois.json` has 5 for Da Lat and 4 for Phu Quoc, with no source metadata. Existing
numbers are not validated by the new collection and are not copied as verified
prices. The new JSON contains 72 unique named place references, six per approved
destination, and one authored three-day example each.

## Scope of verification

Codex read the official Viet Nam National Authority of Tourism pages linked by
each source record. Confirmation is limited to place name and association with
the destination region. It is not proof of current opening, access, tickets,
precise location, route feasibility, weather or reservation availability.

Coordinates, opening hours, prices and duration stay NULL. Unknown price is not
zero/free. Samples refer only to the local destination's place IDs and carry
explicit unverified feasibility warnings; they are author-created examples,
not copied commercial itineraries. Sa Pa includes regional markets, some only
operating on particular days; they are not all placed into a single sample day.
Island/boat, protected-area and religious-site access must be checked before use.

Sources and name coverage:

| Destination | Sources | Named references |
| --- | --- | --- |
| Hà Nội | [official attractions](https://vietnam.travel/things-to-do/11-must-see-attractions-ha-noi) | Six names from the attraction list. |
| Hạ Long | [destination](https://vietnam.travel/places-to-go/red-river-delta/ha-long), [bay attractions](https://vietnam.travel/node/1368) | Bay, three caves, Fighting Cock Islet, Tuần Châu. |
| Sa Pa | [destination](https://vietnam.travel/places-to-go/northern-midlands-mountains/sapa), [regional travel](https://vietnam.travel/things-to-do/sapa-itinerary-sustainable-travellers) | Fansipan, two villages, two markets and a named Tả Phìn bathhouse. |
| Ninh Bình | [destination](https://vietnam.travel/places-to-go/red-river-delta/ninh-binh) | Six named sites in the destination section. |
| Huế | [destination](https://vietnam.travel/places-to-go/north-central-coast/hue) | Citadel, three tombs, Đông Ba and Thiên Mụ. |
| Đà Nẵng | [destination](https://vietnam.travel/places-to-go/south-central-coast-central-highlands/da-nang) | Six named regional sites including Son Tra and its Lady Buddha landmark. |
| Hội An | [official attractions](https://vietnam.travel/things-to-do/the-best-ways-to-explore-the-ancient-town-of-hoi-an) | Ancient town, bridge, house, museum and two beaches. |
| Nha Trang | [destination](https://vietnam.travel/places-to-go/south-central-coast-central-highlands/nha-trang) | Beach, two islands and three cultural sites. |
| Đà Lạt | [destination](https://vietnam.travel/places-to-go/south-central-coast-central-highlands/dalat) | Lake, market, station, Lang Biang, Bidoup and Linh Phuoc. |
| TP.HCM | [destination](https://vietnam.travel/places-to-go/southeastern-vietnam/ho-chi-minh-city) | Six named urban cultural/market sites. |
| Phú Quốc | [destination](https://vietnam.travel/places-to-go/mekong-delta/phu-quoc), [named coastal sites](https://www.vietnam.travel/things-to-do/sunset-in-phu-quoc) | Six named island/coastal sites. |
| Cần Thơ | [official regional guide](https://vietnam.travel/things-to-do/can-tho-glimpse-river-and-garden) | Six named sites in the guide. |

No source paragraphs or photos are copied. Publisher pages retain their rights;
the collection does not invent an open licence or grant distribution permission.
Rights/distribution remain a recorded release consideration rather than a claim
of licence clearance. Some historic city URLs redirect after administrative
changes, including Hoi An to Da Nang; the collection uses an actual Hoi An article
and keeps the Owner's approved travel destination identity separate from that
website's current administrative categories.

## Testing / Problems / next integration

`node --test test/catalogue_readiness_test.mjs` checks twelve IDs, minimum depth,
source bindings, unique place IDs, destination-bound sample references and truthful
NULL/unknown markers. Negative controls reject invented sources, implicit free
prices, fabricated coordinates, cross-destination samples and false verification.
Source reading is manual evidence; tests do not reverify the online page or
operator availability. The PR supplies CI status on its exact commit.

Runtime publication and manual/AI planning with all twelve destinations are NOT
RUN. Phase 3 must consume a checked catalogue, resolve/validate location and
access, and disclose unknown facts. Do not feed these NULL values into an old
integer-only POI adapter that silently converts unknown costs to zero. The current
Decision Engine data is not overwritten by this packet. AC-052 runtime remains
open; reference depth preparation does not close the complete criterion.

Lesson: validate provenance and identities separately from operational details.
An official mention can support a place name while its price and availability
remain unknown; the UI and adapters must preserve that distinction.
