# hebbsheffer-pages

Combined site for Hebb & Sheffer: a hand-maintained marketing site at the
root (Webflow export — `index.html`, `css/`, `images/`, `js/`, `fonts/`,
`videos/`) plus the inReach client portal SPA under `app/`, deployed
together to Firebase Hosting.

The portal SPA itself is built from a separate repo, [`saas-vue`](../saas-vue),
and synced in here — this repo does not build the SPA itself.

## Sites

- **`beta.hebbsheffer.ca`** → Firebase Hosting target `hebbsheffer-ca-staging`. Staging — safe to deploy to freely.
- **`www.hebbsheffer.ca`** → Firebase Hosting target `hebbsheffer-ca-prod`. **As of 2026-08, this is not live** — `www.hebbsheffer.ca` is still served by a separate legacy AWS CloudFront/S3 setup untouched since 2022. Confirm with Darrin before deploying to prod; it won't be user-facing yet, but don't assume that stays true forever.

Both targets live on the `inreach-ntrprod` Firebase project.

## Rebuilding the portal SPA and deploying

Whenever `saas-vue` changes need to go live here:

```bash
# 1. Build saas-vue with the /app/ base path.
#    This is required, not optional: router.js picks hash-mode vs
#    history-mode routing based on Vite's BASE_URL. A plain `vite build`
#    (or `npm run build`) defaults to base '/' and produces a router
#    that expects to own the whole domain — broken once served under
#    /app/, since this repo's firebase.json only SPA-falls-back paths
#    under /app/**, not the whole site (root is the static marketing page).
cd ../saas-vue
npx vite build --base=/app/

# 2. Sync ONLY the built bundle in. This preserves the hand-maintained
#    app/index.html shell (real <title>/favicon already filled in —
#    saas-vue's own dist/index.html ships with unfilled {{metaTitle}}/
#    {{linkFavicon}} template placeholders that are never substituted
#    server-side here) and leaves the marketing root untouched.
cd ../hebbsheffer-pages
rsync -a --delete ../saas-vue/dist/inreach-assets/ app/inreach-assets/

# 3. Update the hashed filenames referenced in app/index.html to match
#    the new build (grep the new index.*.js / vendor.*.js names and
#    hand-edit the <script src>/<link> tags in app/index.html).
grep -oE 'index\.[a-f0-9]+\.js|vendor\.[a-f0-9]+\.js' app/inreach-assets/index.*.js 2>/dev/null
ls app/inreach-assets/ | grep -E '^(index|vendor)\.'

# 4. Deploy FROM THIS REPO — never from saas-vue (see below).
firebase deploy --only hosting:hebbsheffer-ca-staging
# or hosting:hebbsheffer-ca-prod, with explicit confirmation first.
```

Commit both the `app/index.html` diff and the renamed `app/inreach-assets/*`
files together — the old-hash files should show as deleted, new-hash files
as added (or renames, if git detects the similarity).

## Why not just `firebase deploy` from `saas-vue`?

`saas-vue` intentionally has **no Firebase Hosting config of its own** —
it was removed after a plain `firebase deploy` there once silently
replaced this repo's whole combined site with `saas-vue`'s bare `dist/`
output (SPA only, no marketing homepage, and defaulting to broken
history-mode routing under `/app/`). If you ever see hosting config
reappear in `saas-vue/firebase.json`, that's a regression — remove it
again rather than using it.

## Caching

`app/index.html` and `app/` are served with `Cache-Control: no-cache`
(see the `headers` block in `firebase.json`) so browsers revalidate the
app shell on every load instead of Firebase Hosting's default
`max-age=3600`. Without this, a browser that loaded the app shell before
a deploy can keep running it — with dead references to since-deleted,
content-hashed chunk files — for up to an hour after, surfacing as
"Whoops, there was a problem loading that page." The hashed asset files
themselves are unaffected and stay long-cached, which is correct: only
the entrypoint HTML needs to always revalidate.

## Data model notes (Firestore, `inreach-ntrprod` project)

- `landingPages/{team}.site.customDomain` (array) drives inbound routing
  — which team's data loads for a given custom domain — via
  `saas-vue/src/main.js`'s `getSiteMetadata()`.
- `landingPages/{team}/home/{team}` holds `landingType` and `customDomain`
  (a single string — the Home button's target URL), both read live and
  unpublished on every page load. Settings → General's "Home Type"/"Home
  Domain" fields in the admin console write here directly; there's no
  publish step for these two fields specifically, unlike profile content.
