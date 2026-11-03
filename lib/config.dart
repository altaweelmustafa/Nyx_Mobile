import 'package:flutter/foundation.dart' show kIsWeb;

/// Homelab server hosting the shared track catalog (audio/images/lyrics)
/// and orc's import pipeline. Reachable over Tailscale.
///
/// The web build is served by a proxy in front of that same server (see
/// deploy/web), so it uses the address the page was loaded from instead.
String get kDefaultServerUrl => kIsWeb ? Uri.base.origin : kHomelabServerUrl;

/// The homelab server's direct address, as stored in the desktop/Android
/// library's track URLs.
const kHomelabServerUrl = 'http://100.105.90.110:8086';

/// Web only: a copy of the desktop library (liked songs, playlists, profile),
/// put on the server by scripts/publish_library.sh. A fresh web install
/// starts from it; Sync Library can restore it again later.
const kWebLibrarySnapshot = 'library/brager.db';
const kWebLibraryAvatar = 'library/avatar.jpg';

/// Shown on the Settings screen -- keep in sync with pubspec.yaml's `version`.
const kAppVersion = '1.0.0';

/// Discord Rich Presence application id, used by DiscordPresenceService to
/// show the currently playing track on your Discord profile while the
/// Discord desktop client is running. Create an application at
/// https://discord.com/developers/applications, copy its "Application ID"
/// from the General Information tab, and put it here -- the placeholder
/// below won't authenticate against any real Discord app.
const kDiscordClientId = '1544480251604762654';

/// Key of the Rich Presence "Art Asset" (Developer Portal -> your app ->
/// Rich Presence -> Art Assets) shown as the activity's large image.
/// Per-track cover art isn't possible here: Discord fetches asset images
/// server-side through its own media proxy rather than trusting the local
/// client's network access, and that proxy can't reach our homelab's
/// Tailscale-private address (confirmed live: a raw external URL there
/// comes back as a 502 from media.discordapp.net). A fixed uploaded asset
/// needs no public exposure and just always works. Must match the key you
/// give the image when uploading it, exactly.
const kDiscordLargeImageKey = 'nyx_logo';
