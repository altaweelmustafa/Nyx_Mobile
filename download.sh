#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# Brager — asset downloader
# Run from the root of your Flutter project:  bash download_assets.sh
# ─────────────────────────────────────────────────────────────────
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${BLUE}[info]${NC}  $1"; }
success() { echo -e "${GREEN}[done]${NC}  $1"; }
warn()    { echo -e "${YELLOW}[warn]${NC}  $1"; }

# ── 1. Create folders ─────────────────────────────────────────────
info "Creating asset directories..."
mkdir -p assets/audio
mkdir -p assets/images
mkdir -p assets/lyrics
success "Directories ready"

# ── 2. Helper: download with curl, skip if already exists ─────────
download() {
  local url="$1"
  local dest="$2"
  local label="$3"

  if [ -f "$dest" ]; then
    warn "$label already exists, skipping"
    return
  fi

  info "Downloading $label..."
  curl -L --silent --show-error --output "$dest" "$url"
  success "$label → $dest"
}

# ── 3. On My Way ──────────────────────────────────────────────────
echo ""
echo "━━━  On My Way — Alan Walker & Sabrina Carpenter  ━━━"

download \
  "https://cdnt-preview.dzcdn.net/api/1/1/a/9/c/0/a9cf320ef32bb89370dad691a56abf99.mp3" \
  "assets/audio/on_my_way.mp3" \
  "on_my_way.mp3"

download \
  "https://cdn-images.dzcdn.net/images/cover/cfc6d9793a6d36ffa98ce6a19cf02acb/500x500.jpg" \
  "assets/images/on_my_way.jpg" \
  "on_my_way.jpg"

# Lyrics — written inline so you don't need a separate server
if [ ! -f "assets/lyrics/on_my_way.lrc" ]; then
  info "Writing on_my_way.lrc..."
  cat > assets/lyrics/on_my_way.lrc << 'LRC'
[ti:On My Way]
[ar:Alan Walker, Sabrina Carpenter & Farruko]
[al:On My Way]
[00:00.00] On My Way
[00:17.50] I heard, I had a dream
[00:20.50] That you and I would still be here
[00:23.50] Now you're miles away
[00:26.50] But I see you everywhere
[00:29.50] And I keep going back
[00:32.50] Can't stop this feeling in my veins
[00:35.50] I tried to fight it back
[00:38.50] But it seems there's just no way
[00:41.50] I've never been so wide awake
[00:44.50] No, nobody but me can keep me safe
[00:47.50] And I'm on my way
[00:50.50] The blood moon is on the rise
[00:53.50] The fire burning in my eyes
[00:56.50] No, nobody but me can keep me safe
[00:59.50] And I'm on my way
[01:02.50] So then, when I'm finished
[01:05.50] I'm all 'bout my business and
[01:08.50] Ready to save the world
[01:11.50] I'm taking my misery, make it my bitch
[01:14.50] Can't be everyone's favorite girl
[01:17.50] So take aim and fire away
[01:20.50] I've never been so wide awake
[01:23.50] No, nobody but me can keep me safe
[01:26.50] And I'm on my way
LRC
  success "on_my_way.lrc written"
else
  warn "on_my_way.lrc already exists, skipping"
fi

# ── 4. Summertime Sadness ─────────────────────────────────────────
echo ""
echo "━━━  Summertime Sadness — Lana Del Rey  ━━━"

download \
  "https://cdnt-preview.dzcdn.net/api/1/1/7/4/1/0/7415ee6d2566908ce97889ab9184a2bd.mp3" \
  "assets/audio/summertime_sadness.mp3" \
  "summertime_sadness.mp3"

download \
  "https://cdn-images.dzcdn.net/images/cover/4c2c6143c3e83a01ea73517c57d1d138/500x500.jpg" \
  "assets/images/summertime_sadness.jpg" \
  "summertime_sadness.jpg"

if [ ! -f "assets/lyrics/summertime_sadness.lrc" ]; then
  info "Writing summertime_sadness.lrc..."
  cat > assets/lyrics/summertime_sadness.lrc << 'LRC'
[ti:Summertime Sadness]
[ar:Lana Del Rey]
[al:Born To Die]
[00:00.00] Summertime Sadness
[00:18.00] Kiss me hard before you go
[00:21.50] Summertime sadness
[00:25.00] I just wanted you to know
[00:28.50] That baby you're the best
[00:32.00] I got my red dress on tonight
[00:35.50] Dancing in the dark in the pale moonlight
[00:39.00] Done my hair up real big, beauty queen style
[00:42.50] High heels off, I'm feeling alive
[00:46.00] Oh my God, I feel it in the air
[00:49.50] Telephone wires above are sizzlin' like a snare
[00:53.00] Honey I'm on fire, I feel it everywhere
[00:56.50] Nothing scares me anymore
[01:00.00] Kiss me hard before you go
[01:03.50] Summertime sadness
[01:07.00] I just wanted you to know
[01:10.50] That baby you're the best
[01:14.00] I got that summertime, summertime sadness
[01:17.50] Su-su-summertime, summertime sadness
[01:21.00] Got that summertime, summertime sadness
[01:24.50] Oh oh oh oh
LRC
  success "summertime_sadness.lrc written"
else
  warn "summertime_sadness.lrc already exists, skipping"
fi

# ── 5. Summary ────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  All assets downloaded. File tree:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
find assets/audio assets/images assets/lyrics -type f | sort | sed 's/^/  /'
echo ""

# ── 6. Reminder ───────────────────────────────────────────────────
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Make sure pubspec.yaml includes:"
echo "       - assets/audio/"
echo "       - assets/images/"
echo "       - assets/lyrics/"
echo "  2. Run: flutter pub get"
echo "  3. In mock_data.dart, update audioUrl to:"
echo "       'asset:///assets/audio/on_my_way.mp3'"
echo "       'asset:///assets/audio/summertime_sadness.mp3'"
echo ""
