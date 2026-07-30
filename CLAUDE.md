# Umubano Impore Website — Project Handoff

This file is for Claude (in Claude Code, or any future session) to read first. It explains
what this project is, exactly how it currently works, what's fragile about it, and what the
person wants to happen next.

## What this is

A website for **Umubano Impore**, a non-profit working on maternal/child health, education,
and rural development in Huye district, southern Rwanda. It mirrors the structure of the
organisation's existing site, https://www.impore.be/, but is a fresh build, not a copy of
that site's code.

The person building this (Ghislain) is non-technical and directs changes conversationally —
expect requests like "make the text bigger", "I lost my posts, bring them back", "add a video
option". Keep that in mind: explanations should stay in plain language, not jargon.

## Architecture: now backed by a real Supabase database (migration is DONE)

The entire site is still **one self-contained HTML file** (`index.html`) — HTML, CSS, and
vanilla JS all in one file, no build step, no server. It used to depend entirely on
Claude.ai's injected `window.storage`, which meant it only worked inside a live Claude.ai
artifact session. **That migration is now complete** — as of the current version:

1. **Storage**: `siteStorage` (near the top of the `<script>`) talks directly to a Supabase
   project via `@supabase/supabase-js` (loaded from a CDN `<script>` tag right before the main
   script). `SUPABASE_URL` and `SUPABASE_ANON_KEY` are hardcoded there — this is intentional and
   safe, the anon key is meant to be public, protected by row-level security policies on the
   database side (see `supabase-schema.sql`). Every visitor's browser now reads/writes the same
   real database, from anywhere the file is opened — a downloaded copy, GitHub Pages, Cloudflare
   Pages, a custom domain, all share the same data.
   - `window.storage` (Claude.ai) and a browser's own `localStorage` are still supported as
     fallbacks, in that priority order, only if `supabaseClient` fails to initialize (e.g. the
     CDN script didn't load). They are NOT kept in sync with Supabase or each other — Settings →
     Backup can move content between whichever store is currently active.
2. **Admin auth**: no more hardcoded passcode. Admin signs in with a real email + password via
   Supabase Auth (`supabaseClient.auth.signInWithPassword`). Add/manage admin users from the
   Supabase dashboard → Authentication → Users. `state.isAdmin` is derived from whether there's
   a live Supabase session (checked on load via `auth.getSession()`), not a client-side flag
   that could be faked — actual write access is enforced by RLS policies requiring
   `auth.role() = 'authenticated'`, checked server-side by Postgres itself, not by this JS file.
3. **Translate button**: still only works inside a live Claude.ai session (calls the Claude API
   bridge Claude.ai injects) — this was NOT part of the Supabase migration and remains a known
   limitation. Outside Claude.ai, admin fills in French/Kinyarwanda tabs by hand (fully
   supported, see "Language architecture" below).

### Deployment status

Pushed to GitHub, connected to Cloudflare Pages for auto-deploy on every push — this is now
the live, independent version of the site. If you're picking this up in a future session,
check `git log` / `git remote -v` in this folder rather than assuming anything here is stale.

## File layout

```
umubano-impore-project/
  index.html    <- the entire site (this is the only real deliverable)
  README.md     <- shorter, person-facing instructions (admin passcode, how to publish, etc.)
  CLAUDE.md     <- this file
```

## Site structure / pages

Sidebar nav (in `PAGES` array near the top of the `<script>`):
- **Home** (hidden from nav list, reached via a "Home" link at the top of the sidebar)
- **Our non-profit organisation** → Mission, Structure, Board members, Documents
- **Projects** → Marraine's Home, Primary education, Combating malnutrition, Follow-up Babies,
  Rural Development
- **Join in** → Volunteer work, Internships, Donations, Testimonials
- **Contact** → E-mail, Registered Office
- **Sponsors** → Thank you very much!
- **Settings** (last item in sidebar) → About, Contact info, Support us, **Admin access**

Every page/section above (except the Admin access control panel) is a generic "section" that
can have admin-published posts on it — there's nothing special about Projects vs. Contact
structurally, they all use the same `renderSectionPage` / composer / feed machinery.

## Admin system

- Real auth via Supabase (email + password) — see "Architecture" above. No passcode exists
  anymore; do not reintroduce one as a shortcut.
- Sign in from **Menu → Settings → Admin sign-in**. The nav item itself is hidden from ordinary
  visitors — revealed only by tapping the top-bar logo 8 times quickly, or by already having a
  valid session on that device (see `adminEntryVisible()` / `rememberAdminDevice()`).
- Once signed in (`state.isAdmin = true`, derived from a real Supabase session), every page
  shows a composer for new posts, and every post shows **Edit** and **Delete** buttons.

## Language architecture (English / Français / Ikinyarwanda)

- All *fixed UI text* (menu labels, button text, page titles/descriptions) lives in the `UI`
  object (keyed `en`/`fr`/`rw`) and is accessed via the `t('key')` helper. This is fully
  pre-translated by hand and always works, with no API dependency.
- All *admin-authored content* (post titles/bodies/image captions, the home page founder story)
  is stored as `{ en: "...", fr: "...", rw: "..." }` objects, filled in **at write time**, not
  translated live when a visitor loads the page. This was a deliberate architecture change after
  live-translate-on-read proved unreliable (see "Known incidents").
- The composer has per-language tabs. Admin writes in English, then can press **"Translate from
  English"** (calls the Claude API bridge — Claude.ai only) to auto-fill French/Kinyarwanda, or
  can just type/paste translations manually into those tabs. Either way, whatever is saved in
  each tab is exactly what's shown to a visitor in that language — no live translation ever
  happens on the read path anymore.
- **Kinyarwanda quality caveat**: all Kinyarwanda text in this project (seed content and
  anything auto-translated) was produced by Claude, not reviewed by a native speaker. Flag this
  if precision matters (e.g. before print materials or anything formal).

## Storage architecture (all via `siteStorage`, backed by a Supabase table `kv_store`)

Rather than one Supabase table per content type, everything goes through a single
`kv_store(key text primary key, value text)` table, accessed through the exact same
`get/set/delete/list(prefix)` interface the code always used for `window.storage` — this was a
deliberate choice to let the Supabase migration touch only the storage adapter and the auth
flow, not the ~30 call sites throughout the file that read/write content. `list(prefix)` maps to
`select key from kv_store where key like 'prefix%'`. RLS policies (see `supabase-schema.sql`)
allow public SELECT on everything except `visitormsg_*` keys, public INSERT only on
`visitormsg_*` keys (the "write to us" feature), and full read/write for any authenticated
(signed-in admin) session.

- **Posts**: one storage key *per individual post*, not one array per page. Key format:
  `post_<pageId>_<secId>_<postId>`. Discovered via `siteStorage.list(prefix)` then fetched
  individually. This was a deliberate fix after the original "one JSON array per page"
  design blew past the 5MB per-key storage limit once multi-image/video posts existed (see
  "Known incidents").
  - Post shape: `{ id, ts, title:{en,fr,rw}, text:{en,fr,rw}, image, media:[...], }`
  - `media` is an array of `{ type:'image'|'video', image|video: <url or base64>, caption:{en,fr,rw} }`.
    Multiple images/videos per post are supported, each with its own caption.
  - `image` (top-level, singular) is kept only as a legacy/fallback field equal to the first
    media item's image — the actual rendering always prefers `media`.
- **Home page story**: single key `home_story_v2`, shape `{ founderTitle, founderName,
  founderText, heroImage, founderPhoto, images:[] }` (all text fields are `{en,fr,rw}`). Note:
  this is *not* yet split into per-field keys the way posts are — if it ever grows too large
  (e.g. many gallery images), it could hit the same size-limit problem posts used to have.
- **Per-page header photo**: key `pageheader_<pageId>_<secId>`, plain string (URL or base64).
  Falls back to `PAGE_HEADER_DEFAULTS[mapKey]` if set, else to the home page's own hero photo
  (`HERO_PHOTO`), so no page is ever left with no image at all.
- **Legacy migration**: `migrateLegacyPostsIfNeeded()` looks for the old single-array key
  (`posts_<pageId>_<secId>`) and moves any posts found there into the new per-post-key format,
  **only deleting the old key once every post has been confirmed migrated**. Writes are done
  sequentially with a small delay between each (see "Known incidents" — this used to be
  `Promise.all` and it caused real problems).

## Recovered content from the old impore.be site

Because of a data-loss incident (see below), six home page posts and five Projects-page
overview posts were manually recovered by fetching https://www.impore.be/ with `web_fetch`,
translating the Dutch text to English by hand, and re-hosting the *images* by linking directly
to their original impore.be URLs (images could not be downloaded — `web_fetch` returned
"Image content is not supported" for binary image content, so there was no way to re-upload them
locally). These live in two constants near the top of the script:

- `RECOVERED_HOME_POSTS` — 6 posts, seeded onto the Home page.
- `SEED_POSTS_BY_PAGE` — one overview post each for `projects:marraine`,
  `projects:primary-education`, `projects:malnutrition`, `projects:babies`,
  `projects:rural-dev`.

These are seeded automatically (`seedPageIfNeeded()`) the *first time* a page is visited with
zero existing posts — it will never overwrite anything already published. **If the person asks
where their old posts are again, check these constants before assuming they're gone.**

**Not yet recovered**: the "Our non-profit organisation" pages (Mission/Structure/Board
members/Documents — old site path `/onze-vzw/`) and the "Join in" pages
(Volunteer/Internships/Donations/Testimonials — old site path `/doe-mee/`). The person was
asked if they wanted these pulled over too; confirm before doing more scraping work, and note
that **images linked this way depend on impore.be staying online** — if that old site is ever
taken down, every image that links to it (dozens, across recovered posts) will break, and would
need to be re-uploaded from local copies instead.

## Known incidents (read before touching storage code again)

1. **Storage size limit.** Original design stored *all* posts for a page as one JSON array
   under one key. Once multi-image posts existed, a single save could push that array over the
   platform's 5MB-per-key limit, and the whole save would fail with "Storage set failed:
   Internal server error." Fixed by moving to one key per post (see above).
2. **Silent data loss during migration.** The first version of the migration-to-per-post-keys
   logic used `Promise.all` to write all posts in parallel, each wrapped in a bare
   `.catch(()=>{})`, and then **unconditionally deleted the old combined key** regardless of
   whether every individual write actually succeeded. If any single write silently failed, that
   post's data was gone, and the backup was deleted anyway. This is genuinely why the person
   lost a real, hand-written post they'd published. Fixed by: only deleting the old key once
   every post has been confirmed saved, and by adding a merge-fallback in `loadPosts()` that
   also reads the old key (if it still exists for any reason) and folds in anything missing.
3. **Storage write rate limiting.** Separately from size limits, Claude.ai's storage API can
   return `"Storage set failed: Message rate limit exceeded. Reload to continue."` if too many
   writes happen in a short burst — this hit hard right after the 11-post recovery seeding ran
   (originally `Promise.all` again). Fixed by writing sequentially with a real ~600ms delay
   between each write (`sleep()` helper), and by breaking out of a seeding/migration loop
   immediately on the first failure rather than retrying the same batch over and over on every
   reload. If this error reappears, it's most likely a **session-wide Claude.ai rate limit**
   unrelated to this code (the person hit this again even after the fix, in a very long chat
   session with heavy tool use) — the fix at that point is a fresh chat/session, not more code
   changes.
4. **Environment confusion.** The person spent a long stretch debugging "translation doesn't
   work" and "posts disappear" before it became clear they were sometimes testing by opening
   the *downloaded* `index.html` directly in Microsoft Edge (`file:///C:/Users/hp/Downloads/...`)
   rather than the live Claude.ai artifact. Always ask **"what's in your browser's address bar
   right now"** early if storage/translation behaviour is being reported as broken — don't
   assume it's a code bug before ruling this out.

## Design system

- Single accent colour used everywhere (deliberately reduced from an earlier 3-shade green
  system, then later deepened again because the palest tint read as "basically white" against
  photos) — CSS custom properties `--green-deep`, `--green-mid`, `--green-bright` are currently
  all the same value (`#1E7A46`), `--green-pale` (`#CFEAD9`) is the page background, `--ink` is
  pure black for body text. If asked to touch colours again, change the variables, not
  individual rules — everything reads off them.
- Headings use `'Fraunces', serif` (loaded from Google Fonts), body text uses `'Karla', sans-serif`.
- Hero photo is full-bleed (edge-to-edge, no rounded corners/margin) at the very top of the page,
  rendered into a dedicated `#homeHero` div *outside* the constrained `.page-wrap` container so
  it can span the full viewport width — this required restructuring away from an earlier version
  where the hero lived inside the padded content column.
- Posts render as an animated, auto-advancing horizontal carousel (`.feed-grid`, flex + scroll-
  snap), not a static grid — cards fade/slide in on load and auto-scroll every ~4s, pausing on
  any user interaction (hover/touch/scroll/wheel).
- Admin rich-text formatting: **bold** `**`, *italic* `*`, __underline__ `__`, ~~strikethrough~~
  `~~`, plus one-click UPPERCASE/lowercase/Capitalize buttons that transform the literal
  selected text (no markup needed for case changes). Parsed by `formatRichText()`.

## Things to sanity-check before making further changes

- Run a quick syntax check after any edit: extract the `<script>` contents and run them through
  `node -e "new Function(script)"` — this project has repeatedly caught real syntax breaks this
  way (stray leftover code fragments, unmatched braces from partial edits) before they reached
  the person.
- This file is large (single HTML file with everything inline, several images embedded as
  base64). Keep an eye on total file size creeping up — it's currently around 600KB.
- The person cannot see or debug JavaScript errors themselves in any technical sense — when
  something goes wrong, get the *exact* error text from them (they're good about copy-pasting
  it verbatim) and reason from that, don't ask them to open dev tools and describe what they see.
