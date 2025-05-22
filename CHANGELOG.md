## 3.0.0

- Dropped `loggerx` package
- Added official `logging` package
- Upgraded other dependencies to the latest (major) versions

## 2.0.4

- Added Flutter App Demo Video to the README

## 2.0.3

- Parameter `bssid` of `ProvisioningRequest`s factory `fromStrings` is not required anymore. If ommited, `bssid` will default to `00:00:00:00:00:00`. 

## 2.0.2

- Implemented CI/CD with GitHub Actions
    - Validate PR (while working on PR)
    - Publish package to pub.dev (on publishing a release)

## 2.0.1

- Fixed broken link of head image in README

## 2.0.0

- Upgrade loggerx to v2
- Upgrade lints to v3
- Set SDK constraints to ">=3 <4"
- Bump other dependencies to align with lock file
- Fix code warnings

## 1.1.11

- Checking if isolate stream is open before sinking event data

## 1.1.10

- YouTube demo video

## 1.1.9

- Using absolute url for cover photo since otherwise it's not shown on pub.dev

## 1.1.8

- Cover photo

## 1.1.7

- Dart format

## 1.1.6

- Resolved static analysis warnings and recommendations.

## 1.1.5

- Checking for the minimum length of WiFi password (according to WPA standard, minimumum length of password is 8 characters).

## 1.1.4

- Dependencies versions bumps
- Security update, deprecated AESFastEngine replaced with AESEngine

## 1.1.3

- README updated (removed info about multicast mode)

## 1.1.2

- README updated

## 1.1.1

- Expose `ProvisioningResponse`

## 1.1.0

- Common protocols send bottlenecking
- Simplified subscribing to provisioner stream
- Exceptions inline docs

## 1.0.2

- Fixed receiving response (first byte) for EspTouch.

## 1.0.1

- Fixed license badge and repo url.

## 1.0.0

- Initial version.
    - EspTouch and EspTouchV2 protocols
