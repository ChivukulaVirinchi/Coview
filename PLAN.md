# CoView - Open Source Release Plan

> A real-time collaborative browsing app built with Phoenix LiveView

## Overview

**CoView** lets a leader share their browser view with followers in real-time via DOM transfer (not video streaming). Uses a Chrome extension for leaders, Phoenix LiveView for viewers.

**Goals**:
1. Work reliably as a co-browsing tool
2. Showcase Elixir/Phoenix's real-time capabilities  
3. Be visually stunning and memorable
4. Easy for anyone to try (no Chrome Web Store approval needed)

**Architecture**: Ephemeral by design - no database, rooms live in memory, auto-cleanup when empty.

---

## Design Vision

### Aesthetic Direction: "Broadcast Control" - Dark, Cinematic, Live

The viewer experience should feel like watching a **live broadcast** or being in a **control room**. Dark interface with electric accents. The shared view is the "main screen" - everything else is peripheral instrumentation.

**Why this works**:
- Dark UI keeps focus on shared content (which could be any website)
- Broadcast aesthetic reinforces "you're watching something live"
- Technical/professional appeals to developers, support teams
- Memorable - most screen-sharing tools look generic; this feels purposeful

**Tone**: Confident, technical, cinematic. Bloomberg terminal meets Twitch stream.

### Typography

| Role | Font | Fallback |
|------|------|----------|
| Display | Instrument Serif | Georgia, serif |
| Body | Geist | system-ui, sans-serif |
| Mono | Geist Mono | SF Mono, monospace |

*Same fonts as Sutra UI for consistency, but applied with a darker, more technical aesthetic.*

### Color Palette

```css
:root {
  /* Backgrounds - deep, rich blacks */
  --bg: #09090b;
  --bg-elevated: #18181b;
  --bg-subtle: #0f0f12;
  --bg-muted: #27272a;
  
  /* Foregrounds */
  --fg: #fafafa;
  --fg-secondary: #a1a1aa;
  --fg-muted: #71717a;
  
  /* Borders */
  --border: #27272a;
  --border-strong: #3f3f46;
  
  /* Primary accent - electric cyan (LIVE feel) */
  --accent: #22d3ee;
  --accent-glow: rgba(34, 211, 238, 0.4);
  --accent-subtle: rgba(34, 211, 238, 0.1);
  
  /* Secondary - warm amber (viewers, warnings) */
  --warm: #fbbf24;
  --warm-glow: rgba(251, 191, 36, 0.4);
  
  /* Status */
  --success: #4ade80;
  --error: #f87171;
}
```

### The Unforgettable Elements

1. **"LIVE" Indicator**: Pulsing dot with glow effect, always visible when leader is connected

2. **Viewer Presence Orbs**: Glowing circles that:
   - Materialize with a bloom effect on join
   - Pulse gently when idle
   - Show connection quality via glow intensity
   - Fade out gracefully on leave
   
3. **Cursor Spotlight**: Leader's cursor has a subtle radial glow - makes it instantly visible on any content

4. **Stats Overlay**: Minimal but informative - viewer count, duration, latency - like a broadcast HUD

5. **Room Entry Animation**: When entering a room, the shared view "powers on" like a monitor

### Spatial Composition

- **Asymmetric layout**: Shared view dominates (85%), presence panel slides from right
- **Floating controls**: Minimal chrome, controls appear on hover
- **Generous negative space** around the main view
- **Full-screen mode**: Truly immersive, only essential HUD elements

### Motion

- **Page load**: Staggered fade-up, elements materialize from darkness
- **Viewer join/leave**: Orb bloom in, fade out with slight scale
- **Live indicator**: Continuous subtle pulse (CSS animation)
- **Hover states**: Glow intensifies, borders brighten
- **Room transition**: View "powers on" with scan-line effect

---

## Technical Stack

### Current
- Phoenix 1.8+ with LiveView 1.1+
- DaisyUI (Tailwind plugin) - **TO BE REMOVED**
- Heroicons
- morphdom for incremental DOM updates

### Target
- Phoenix 1.8+ with LiveView 1.1+
- **Sutra UI** (from ../sutra_ui) - components + colocated hooks
- Custom CSS design system (dark theme)
- morphdom for incremental DOM updates

---

## Phase 1: Foundation & Migration
**Priority: Critical | Estimate: 1-2 days**

### 1.1 Remove DaisyUI, Add Sutra UI
- [ ] Remove DaisyUI from assets/css/app.css
- [ ] Remove DaisyUI vendor files
- [ ] Add `{:sutra_ui, path: "../sutra_ui"}` to mix.exs
- [ ] Configure Sutra UI in coview_web.ex
- [ ] Import Sutra UI CSS
- [ ] Configure Sutra UI hooks in app.js

### 1.2 Create Dark Theme CSS
- [ ] Define CSS variables (colors, typography, spacing)
- [ ] Create base styles (body, scrollbars, selection)
- [ ] Create utility classes (text-muted, bg-elevated, etc.)
- [ ] Add animation keyframes (fade-up, pulse, glow, bloom)
- [ ] Add grain/noise texture overlay

### 1.3 Fix Remaining Bugs
- [ ] Verify morphdom iframe race condition fix works
- [ ] Test with real websites (Gmail, Twitter, complex SPAs)
- [ ] Handle edge cases: shadow DOM, web components
- [ ] Extension auto-reconnect on disconnect

### 1.4 Room Lifecycle
- [ ] Room timeout: Clean up rooms inactive for 30min
- [ ] Graceful shutdown: Notify viewers when leader stops
- [ ] Handle leader reconnection properly

---

## Phase 2: Homepage Redesign
**Priority: High | Estimate: 1-2 days**

### 2.1 Hero Section
- [ ] Large headline with Instrument Serif: "Watch anyone browse. *Live.*"
- [ ] Animated demo showing real-time sync (CSS or pre-recorded GIF)
- [ ] "Create Room" CTA (generates random code, shows extension prompt)
- [ ] "Join Room" input with sleek dark styling
- [ ] Subtle grid/dot pattern background

### 2.2 How It Works
- [ ] 3-step visual flow with numbered cards
- [ ] Step 1: Install extension (with download link)
- [ ] Step 2: Start sharing (extension screenshot)
- [ ] Step 3: Share link (viewers join instantly)
- [ ] Staggered fade-in animation

### 2.3 Features Section
- [ ] Feature grid with icons
- [ ] Real-time sync, No video (privacy), Works on any site, Open source
- [ ] Hover effects with glow

### 2.4 Live Stats (Showcase Phoenix)
- [ ] Real-time counter: "X rooms active right now"
- [ ] Updates live via PubSub (demonstrates Phoenix power)
- [ ] Subtle pulse animation on count change

### 2.5 Footer
- [ ] GitHub link
- [ ] "Built with Phoenix LiveView" badge
- [ ] Extension download link

---

## Phase 3: Room View Redesign
**Priority: High | Estimate: 2-3 days**

### 3.1 Main Layout
- [ ] Dark background with subtle grain texture
- [ ] Shared view in center with subtle border glow
- [ ] Presence panel on right (collapsible)
- [ ] Floating control bar at bottom

### 3.2 "LIVE" Status Bar
- [ ] Top bar with:
  - Pulsing "LIVE" indicator (when leader connected)
  - Room code (monospace, copyable)
  - Duration: "Streaming for 5m 23s"
  - Latency indicator (optional)
- [ ] Subtle backdrop blur

### 3.3 Presence Panel
- [ ] Leader card at top (highlighted, avatar + "Sharing")
- [ ] Viewer list with:
  - Glowing orb avatars
  - Join time: "Joined 2m ago"
  - Connection quality indicator
- [ ] Join/leave animations (bloom in, fade out)
- [ ] Total viewer count

### 3.4 Shared View Container
- [ ] Dark frame with subtle border
- [ ] "Power on" animation on first DOM load
- [ ] Loading state: skeleton with scan-line effect
- [ ] Waiting state: "Waiting for leader..." with pulsing animation

### 3.5 Ghost Cursor Enhancement
- [ ] Radial glow behind cursor (spotlight effect)
- [ ] Smooth interpolation between positions
- [ ] Click ripple with glow
- [ ] Leader name label (optional, toggleable)

### 3.6 Controls Bar
- [ ] Floating at bottom, appears on hover
- [ ] Fullscreen toggle
- [ ] Copy link button with toast feedback
- [ ] Settings (future: zoom, PiP mode)

### 3.7 Empty/Waiting States
- [ ] No leader: Dark screen with "Waiting for leader to connect..."
- [ ] Leader connected, no DOM: "Leader is preparing to share..."
- [ ] Connection lost: "Reconnecting..." with spinner

---

## Phase 4: Extension Polish
**Priority: Medium | Estimate: 0.5 days**

### 4.1 Popup Redesign
- [ ] Dark theme to match web UI
- [ ] Better connection status display
- [ ] Show current page title being shared
- [ ] Viewer count badge
- [ ] Cleaner layout

### 4.2 Extension Distribution
- [ ] Create `/extension` page on website
- [ ] Download ZIP button
- [ ] Step-by-step installation guide with screenshots
- [ ] Host ZIP in `/priv/static/downloads/`

---

## Phase 5: Open Source Packaging
**Priority: High | Estimate: 1 day**

### 5.1 Documentation
- [ ] **README.md** - Complete rewrite
  - Project description with screenshot/GIF
  - Live demo link
  - Features list
  - Architecture overview
  - Local development setup
  - Deployment guide
  
- [ ] **LICENSE** - MIT

- [ ] **CONTRIBUTING.md** - Basic guidelines

### 5.2 Code Quality
- [ ] Increase test coverage (currently 64%, target 80%+)
- [ ] Document public modules with @moduledoc
- [ ] Remove hardcoded localhost references
- [ ] Environment-based configuration

### 5.3 Repository Setup
- [ ] GitHub repo with good description
- [ ] Topics: elixir, phoenix, liveview, real-time, co-browsing
- [ ] GitHub Actions CI (tests, format check)

---

## Phase 6: Deployment
**Priority: High | Estimate: 0.5 days**

### 6.1 Fly.io Setup
- [ ] `fly launch` - initial setup
- [ ] Configure `fly.toml` for Phoenix
- [ ] Set up secrets (SECRET_KEY_BASE)
- [ ] Enable WebSocket support
- [ ] Custom domain (when ready)

### 6.2 Production Hardening
- [ ] Rate limiting (prevent abuse)
- [ ] Room limits (max viewers per room)
- [ ] Content size limits (max DOM size)
- [ ] CORS configuration for extension

---

## Phase 7: Launch
**Priority: Medium | Estimate: Ongoing**

### 7.1 Soft Launch
- [ ] Deploy to Fly.io
- [ ] Test with real users
- [ ] Gather feedback

### 7.2 Public Launch
- [ ] Elixir Forum post
- [ ] Hacker News "Show HN"
- [ ] Twitter/X announcement
- [ ] Dev.to article

---

## Future Ideas (Post-Launch)

- Voice/video chat integration (WebRTC)
- Text chat sidebar
- Annotations - draw on shared view
- Recording - save and replay sessions
- Multiple leaders - switch who's sharing
- Mobile viewer app

---

## Execution Order

1. **Phase 1.1-1.2** - Foundation: Remove DaisyUI, add Sutra UI, create dark theme
2. **Phase 2** - Homepage: First impression matters
3. **Phase 3** - Room view: The core experience
4. **Phase 4** - Extension: Polish and distribution
5. **Phase 1.3-1.4** - Bug fixes: Can happen in parallel
6. **Phase 5** - Documentation: Before public launch
7. **Phase 6** - Deploy: Get it live
8. **Phase 7** - Launch: Share with the world

---

## Design Assets Needed

- [ ] Logo/wordmark for CoView
- [ ] OG image for social sharing
- [ ] Extension icons (16, 48, 128px)
- [ ] Demo GIF/video for homepage
- [ ] Screenshot for README

---

## Technical Notes

### Global Stats (for homepage live counter)
```elixir
defmodule Coview.Stats do
  use GenServer
  
  # Track: active_rooms, total_viewers
  # Broadcast changes to "stats" topic
  # Homepage subscribes and displays live
end
```

### Presence Enhancement
```elixir
# Track richer metadata
Presence.track(socket, user_id, %{
  role: "follower",
  joined_at: DateTime.utc_now(),
  user_agent: get_user_agent(socket),
  # For country flag (optional)
  country: get_country_from_ip(socket)
})
```

### Room Duration
```elixir
# In Room GenServer state
defstruct [
  # ... existing fields
  :started_at  # Track when leader started sharing
]
```

---

## Questions Resolved

| Question | Decision |
|----------|----------|
| Persistence | Ephemeral - no database |
| UI Framework | Sutra UI (replacing DaisyUI) |
| Theme | Dark "broadcast control" aesthetic |
| Fonts | Instrument Serif + Geist (same as Sutra UI) |
| Presence style | Glowing orbs with animations |
| Homepage stats | Yes - live room count |
| Extension distribution | Self-hosted ZIP download |

---

*Plan created: December 2024*
*Status: Ready for implementation*
