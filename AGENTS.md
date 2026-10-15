# Echo – agent notes

- iOS SwiftUI music app built with **xtool** (SwiftPM, no Xcode project). Swift language mode 5, iOS 17+.
- Search YouTube (keyless InnerTube API, `Services/YouTubeSearch.swift`), tap + to download the m4a audio
  (stream URL via the `YouTubeKit` package, `Services/Downloader.swift`), play offline (`Services/Player.swift`).
- Files live in the app's Documents folder: `library.json`, `Music/<videoID>.m4a`, `Artwork/<videoID>.jpg`.
- The user's name is asked once in onboarding and stored in `@AppStorage("userName")`. No accounts.
- Always dark UI, accent `Color.echoAccent` (`Support/Theme.swift`).
- Build: GitHub Actions (`.github/workflows/ios-xtool.yml`) on repo `erion062/Echo`. Every push builds; get the IPA with
  `gh run download <run-id> -R erion062/Echo -n Echo-ipa -D C:\Users\erion\Desktop` (user sideloads with Sideloadly).
