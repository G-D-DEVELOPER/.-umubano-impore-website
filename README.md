# Umubano Impore — website source

This folder contains the full source code for your website in a single file: `index.html`,
backed by a real Supabase database (see `supabase-schema.sql`).

## How to use it
- **View it:** double-click `index.html` and it opens in any web browser — it talks to the
  live Supabase database no matter where it's opened from (a downloaded file, GitHub Pages,
  Cloudflare Pages, your own domain — all the same data).
- **Host it:** this repo is meant to be connected to Cloudflare Pages (or any static host) —
  every post to GitHub redeploys the live site automatically.
- **Edit it:** send `index.html` back to Claude any time you want changes made for you.

## Admin sign-in
There is no passcode anymore — admin signs in with a real email + password, via Supabase Auth.
To add or change an admin: Supabase dashboard → **Authentication → Users**. Sign in from
**Menu → Settings → Admin sign-in** on the site itself.

## Formatting text
When writing a post or the home page introduction, select any text in the box and tap **B** (bold) or **I** (italic) to format it — this works for titles and body text on every page.

## What admin can do, once signed in
- **Home page:** edit the founder tribute text and name, and replace both the background photo and the founder's photo, all from the "Edit introduction" button.
- **Every other page** (Our non-profit organisation, Projects, Join in, Contact, Sponsors, and the Settings pages — About, Contact info, Support us): a box appears at the top of each page to publish new text/photo updates, with a title field, language tabs, and a Translate button, plus a "Delete" button on every post.
- Visitors never see any of these controls — they only see published content.

## Languages
The language switcher (English / Français / Ikinyarwanda) sits at the bottom of the menu. All the site's own wording (menus, buttons, page titles) is pre-translated and always switches correctly.

**For posted content** (the home page founder text and every update you publish), you fill in each language yourself using tabs in the composer:
1. Write your update in the **English** tab.
2. Press **"Translate from English"** — this asks Claude to fill in the Français and Ikinyarwanda tabs automatically.
3. Check the Français / Ikinyarwanda tabs before publishing. If the automatic translation button ever fails (for example, if the site is opened outside of Claude.ai, where the automatic translation feature is not available), you can type or paste the translation into those tabs yourself.
4. Press **Publish** or **Save**. Whatever is in each tab is exactly what visitors will see in that language.

**Note:** the automatic translate button calls Claude's API directly from the page. This only works while the site is being viewed and used inside Claude.ai. If you host this file elsewhere or open it as a local file, the automatic translate button won't work — but manually typing or pasting text into the Français/Ikinyarwanda tabs always works, everywhere.

## Where your data lives
Posts, photos, the footer, site colours, and everything else are stored in a Supabase
database (project ID in `index.html`, near the top of the `<script>` — look for
`SUPABASE_URL`). Every visitor's browser reads from and writes to that same database, so
nothing is ever stuck in just one browser or one Claude.ai session. `supabase-schema.sql` is
the one-time setup script for a fresh database, kept here for reference.

**Note on Kinyarwanda quality:** both the pre-written text and anything auto-translated were produced by AI and have not been checked by a native speaker. It's worth having someone review the Kinyarwanda wording before relying on it for anything formal.
