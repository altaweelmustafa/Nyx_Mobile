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
