# Echo

A clean, offline-first music player for iOS. Search YouTube, tap **+**, and the song is saved on your
phone to play anywhere, no connection needed. No accounts: Echo asks for your name once and greets you with it.

Built with SwiftUI + [xtool](https://github.com/xtool-org/xtool). Audio extraction by
[YouTubeKit](https://github.com/alexeichhorn/YouTubeKit).

## Build

Every push runs the GitHub Actions workflow, which uploads an unsigned `Echo.ipa` artifact. Install it with Sideloadly.

Local (macOS/Linux with xtool): `xtool dev build --ipa -c release`.
