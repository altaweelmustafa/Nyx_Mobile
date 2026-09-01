/// Homelab server hosting the shared track catalog (audio/images/lyrics)
/// and orc's import pipeline. Reachable over Tailscale.
const kDefaultServerUrl = 'http://100.105.90.110:8086';

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
