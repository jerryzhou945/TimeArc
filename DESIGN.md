---
name: TimeArc Mobile
description: A private pocket album that turns measured screen time into collectible personal memories.
colors:
  primary-lake: "#2D7780"
  primary-lake-soft: "#DAEEF0"
  neutral-canvas: "#F5F6F8"
  neutral-surface: "#FFFFFF"
  neutral-surface-raised: "#ECEFF2"
  neutral-ink: "#17191D"
  neutral-copy: "#58606A"
  neutral-muted: "#626B74"
  neutral-line: "#DCE1E6"
  memory-brown: "#2D2724"
  memory-brown-raised: "#423A36"
  dark-canvas: "#111317"
  dark-surface: "#1A1D22"
  dark-surface-raised: "#23272D"
  dark-ink: "#F2F4F6"
  dark-copy: "#B7BEC7"
  dark-line: "#30353B"
typography:
  display:
    fontFamily: "ui-sans-serif, -apple-system, BlinkMacSystemFont, PingFang SC, HarmonyOS Sans SC, Microsoft YaHei UI, sans-serif"
    fontSize: "32px"
    fontWeight: 700
    lineHeight: 1.12
    letterSpacing: "-0.025em"
  headline:
    fontFamily: "ui-sans-serif, -apple-system, BlinkMacSystemFont, PingFang SC, HarmonyOS Sans SC, Microsoft YaHei UI, sans-serif"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.018em"
  title:
    fontFamily: "ui-sans-serif, -apple-system, BlinkMacSystemFont, PingFang SC, HarmonyOS Sans SC, Microsoft YaHei UI, sans-serif"
    fontSize: "18px"
    fontWeight: 650
    lineHeight: 1.3
  body:
    fontFamily: "ui-sans-serif, -apple-system, BlinkMacSystemFont, PingFang SC, HarmonyOS Sans SC, Microsoft YaHei UI, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.6
  label:
    fontFamily: "ui-sans-serif, -apple-system, BlinkMacSystemFont, PingFang SC, HarmonyOS Sans SC, Microsoft YaHei UI, sans-serif"
    fontSize: "13px"
    fontWeight: 600
    lineHeight: 1.3
rounded:
  control: "10px"
  card: "16px"
  poster: "18px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  xxl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.primary-lake}"
    textColor: "{colors.neutral-surface}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "12px 18px"
    height: "44px"
  button-secondary:
    backgroundColor: "{colors.neutral-surface-raised}"
    textColor: "{colors.neutral-ink}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "12px 18px"
    height: "44px"
  card-memory:
    backgroundColor: "{colors.neutral-surface}"
    textColor: "{colors.neutral-ink}"
    rounded: "{rounded.card}"
    padding: "20px"
  nav-bottom:
    backgroundColor: "{colors.neutral-surface}"
    textColor: "{colors.neutral-copy}"
    typography: "{typography.label}"
    padding: "8px 12px"
    height: "72px"
---

# Design System: TimeArc Mobile

## Overview

**Creative North Star: "The Pocket Time Album"**

TimeArc Mobile feels like a compact album made from measured life. A user-owned wallpaper may sit beneath the entire app, while readable frosted surfaces preserve hierarchy on every tab; without one, the app returns to its solid neutral canvas. Home centers one active card and tucks the neighboring cards beneath it. Its transparent fact strip shows only the recording start date, cumulative recorded time, and recorded usage days.

The system is light-first because people review and share these cards throughout the day. Light wallpaper mode keeps the image visible beneath a very light page veil and translates Home glass, copy, icons, controls, and navigation to dark ink. Dark mode uses the same wallpaper with darker glass and white copy. The warm-brown encyclopedia side of a memory card may stay dark in either theme because it behaves like media, not partial inversion. The four-tab structure remains stable while each tab has one job: Home reveals today's cards, Statistics explains patterns, Memory Lake preserves reports, and Profile owns privacy and settings.

It explicitly rejects generic analytics dashboards, low-contrast cyber glass, technical implementation copy on primary surfaces, productivity scoring, vague personality labels, fabricated precision, and direct imitation of reference products.

**Key Characteristics:**

- Cool neutral canvas with one restrained lake-teal control accent.
- One optional, privacy-safe user wallpaper extends through every tab; the default is a solid color with no bundled image.
- App color appears as content inside a card, never as global navigation chrome.
- Editorial hierarchy without display-font theatrics.
- One primary story, a two-column time encyclopedia, and two pieces of evidence per memory card.
- Motion explains flip, navigation, and share-preview state only.

## Colors

The palette is a cool daylight album: neutral paper-like surfaces without beige warmth, deep ink, and a calm lake-teal accent. A single archival-brown pair is reserved for the encyclopedia side of a card.

### Primary

- **Lake Signal** (`primary-lake`): primary actions, current selection, focus rings, and one meaningful highlight per screen.
- **Lake Wash** (`primary-lake-soft`): selected filters, quiet callouts, and privacy-safe confirmation states.

### Neutral

- **Cool Canvas** (`neutral-canvas`): the light-mode app background.
- **Clean Sheet** (`neutral-surface`): cards, navigation, and share-sheet surfaces.
- **Pressed Sheet** (`neutral-surface-raised`): inactive controls and grouped settings.
- **Album Ink** (`neutral-ink`): headings and primary data.
- **Graphite Copy** (`neutral-copy`): body copy and secondary labels.
- **Archive Gray** (`neutral-muted`): timestamps and low-priority metadata.
- **Hairline** (`neutral-line`): separators when spacing alone is insufficient.
- **Night Canvas / Night Sheet / Night Ink** (`dark-*`): a full dark-mode translation with hierarchy parity.
- **Memory Brown / Raised Memory Brown** (`memory-brown*`): the quiet, low-saturation time-encyclopedia surface; never a global background.

**The One Signal Rule.** Lake teal is the only global accent. Per-app colors are content data and stay inside app artwork, charts, and app identity marks.

**The Proof Contrast Rule.** Body copy must meet WCAG AA. Muted text is never reduced below readable contrast to appear elegant.

## Typography

**Display Font:** platform system sans with Chinese-native fallbacks
**Body Font:** the same platform system sans
**Numeric Font:** the platform's rounded or tabular numeric face when available

**Character:** One familiar sans family keeps the product trustworthy. Hierarchy comes from weight, size, spacing, and content order, not from mixing decorative typefaces.

### Hierarchy

- **Display** (700, 32px, 1.12): share-card statements and monthly recap titles only.
- **Headline** (700, 24px, 1.2): page titles and the one dominant story on a screen.
- **Title** (650, 18px, 1.3): app names, report names, and grouped settings.
- **Body** (400, 15px, 1.6): narrative copy, limited to about 36 Chinese characters per line on mobile.
- **Label** (600, 13px, 1.3): tabs, buttons, filters, and evidence labels.

**The One Breath Rule.** A narrative card leads with one sentence that can be read in a breath. Evidence follows; it never competes at the same typographic size.

**The Honest Number Rule.** Use tabular figures for measured values. Conversions always include words such as "相当于" or "若换算" and never masquerade as recorded behavior.

## Elevation

The system is flat by default. Depth comes from tonal layering and overlap. A small ambient shadow appears only when a card is physically lifted for a flip, when the bottom navigation floats above scroll content, or when a modal share preview sits over the app.

### Shadow Vocabulary

- **Resting Lift** (`0 2px 8px rgba(23, 25, 29, 0.08)`): isolated cards on the cool canvas, without a simultaneous decorative border.
- **Modal Lift** (`0 16px 40px rgba(10, 16, 20, 0.22)`): share preview and monthly story overlay only.
- **Dark Resting Lift** (`0 2px 8px rgba(0, 0, 0, 0.24)`): dark-mode equivalent.

**The Flat Until Needed Rule.** Repeated list rows and statistics remain flat. If every block casts a shadow, the hierarchy has failed.

## Components

### Buttons

- **Shape:** compact, gently curved controls (`10px`) with a minimum `44px` touch height.
- **Primary:** Lake Signal fill with white text, reserved for the one next action.
- **Secondary:** tonal neutral fill with Album Ink text; no outlined ghost-card styling.
- **Hover / Focus / Active:** focus uses a visible lake-teal ring; active compresses to `0.98`; transitions last `160-220ms` with an ease-out curve.

### Chips

- **Style:** full-pill filters use a neutral fill and no border at rest.
- **State:** selected chips use Lake Wash with Album Ink text. Color is never the only state cue; weight and fill change together.

### Cards / Containers

- **Corner Style:** consistent `16px` memory cards and `18px` share posters. Controls remain `10px`; only chips are pills.
- **Background:** neutral surface for informational cards; app color can fill the artwork zone of an app card.
- **Shadow Strategy:** one Resting Lift without a decorative border, or one hairline without a shadow.
- **Internal Padding:** `16-24px`, based on narrative density.

### Inputs / Fields

- **Style:** tonal filled fields with `10px` corners and persistent labels.
- **Focus:** visible 2px lake-teal focus ring with no layout shift.
- **Error / Disabled:** errors use text plus iconography, never color alone; disabled controls retain readable labels.

### Navigation

- **Style:** a familiar four-item bottom navigation with real labels, safe-area padding, and a 72px minimum content height.
- **State:** inactive items are graphite; the active item uses Album Ink plus a Lake Wash lozenge behind the icon. On the immersive Home cover, the same navigation may use white icons on a dark blur while preserving the same geometry and labels. No oversized center action is invented.
- **Persistence:** page scroll, selected period, and card side survive tab changes.

### Private Time Cover

The Home cover is a card backdrop, not a social profile. It does not show an avatar, user name, product slogan, or duplicate page shortcuts. It shows exactly three factual archive values: recording start date, cumulative recorded time, and recorded usage days. A strong scrim guarantees white-text contrast over user imagery. Wallpaper import is local, preserves the original source when its dimensions and storage size are safe, applies one correctly proportioned image layer to every tab, and always offers a reset to the solid-color default.

### App Memory Card

The front uses the same Memory Lake transparency language. With a wallpaper, the central face is nearly clear and unblurred so the image passes directly through; app color appears only as a restrained glow behind the real icon, while the lower copy zone gains a transparent-to-dark readability gradient. Without a wallpaper, a 42% dark fallback protects white-text contrast. One card stays centered while its immediate neighbors overlap underneath and slide into the center when selected; neighboring cards hide their internal copy until selected so text never ghosts through the active card. The back remains a translucent warm-brown time encyclopedia. The prototype activates this treatment with one removable `memory-glass` class so the prior face remains recoverable.

“累计相遇” means retained foreground-record segments, not process launches, song plays, posts read, or videos watched. “第 N 天” means the inclusive calendar span from the earliest retained record; a separate active-day fact states how many days actually contain records.

### Share Keepsake

Sharing exposes one information-complete keepsake instead of a style picker. The composition includes the real app icon when visible, one huge `N 天` or monthly record-day value, a date range, one story line, two facts, and one clearly qualified conversion. The DOM preview, copied text, and 1080×1920 Canvas export use the same structured share model. Anonymous mode hides the app name and icon and neutralizes the app brand color.

### Monthly Story

A full-screen story overlay uses short progress segments, one idea per page, and a persistent close control. Each archived month receives its own original code-drawn seasonal composition, color accent, five-part narrative, and matching Canvas share background. No bundled photograph or user wallpaper is reused as report artwork. Autoplay is off by default. Reduced-motion mode changes pages instantly.

## Do's and Don'ts

### Do:

- **Do** keep the four-tab information architecture and make each tab deliver distinct information.
- **Do** let an optional user wallpaper continue beneath every tab, with readable scrims and a solid-color fallback.
- **Do** derive every personal sentence from real metrics or label it as a conversion.
- **Do** show an anonymized preview before export or sharing.
- **Do** support full light and dark themes, safe-area insets, large text, and reduced motion.
- **Do** preserve app identity with runtime system icons when available, repository assets for known sites, and a clearly generic initial fallback otherwise.

### Don't:

- **Don't** build generic analytics dashboards from repeated bordered statistic cards.
- **Don't** use dark cyber-glass surfaces with low contrast, decorative neon, or effects that compete with content.
- **Don't** place technical implementation copy, package names, database details, or platform APIs on primary product surfaces.
- **Don't** use productivity scoring, moral judgments, or language that frames leisure and communication as failure.
- **Don't** use vague personality labels, fabricated precision, or metaphors presented as measured facts.
- **Don't** directly imitate NetEase Cloud Music, Xiaohongshu, WeChat Moments, Days Matter, or another product's proprietary visual identity.
- **Don't** write “第一次使用,” “累计播放,” or “累计打开” when the retained data only proves foreground record segments.
- **Don't** combine a decorative border with a wide soft shadow, use card radii above `18px`, or nest cards inside cards.
- **Don't** expose raw window titles, contacts, URLs, or other sensitive context in a share image.
