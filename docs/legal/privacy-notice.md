# Sababi Privacy Notice

**Draft, not published.** Sababi: TV Games and Sababi: Remote. Last updated: 2026-11-01.
Provider: Alon Yampolski, Israel. Contact: sababi.play@gmail.com

Sababi does not collect your personal data. We run no server, no account system and no analytics, so we never receive your name, your scores or your sensor readings. Everything below describes what stays on your own devices and your own Wi-Fi.

## 1. What the apps are

- **Sababi: TV Games** runs on a TV or TV box and shows the games.
- **Sababi: Remote** runs on a phone and is the game controller. It uses the motion sensors of the phone.

The two apps talk to each other over the Wi-Fi network you are both on. They do not need the internet to play.

## 2. Information the apps handle

| Information | Where it lives | Why | How long |
|-------------|----------------|-----|----------|
| Player profile: a random ID, a name (up to 10 letters, digits or spaces), an avatar number, personal best scores | On the phone, in the private storage of the app. Up to 8 profiles on a phone | To show your name and avatar on the TV and to keep your best scores | Until you delete the profile, clear the data of the app or uninstall it |
| Last TV you joined: its network address, port, room code and a session token | On the phone | To reconnect after a short break | Until you leave the TV or uninstall |
| Settings: sound volume, vibration, tilt inversion, language | On the phone or on the TV, where you changed it | To remember your choices | Until you uninstall or clear data |
| Motion data: accelerometer and gyroscope readings | Sent from the phone to the TV about 60 times a second while you are connected. Not saved | To steer the game | Used at once and discarded |
| Name, avatar and scores of the players in the current game | On the TV, in memory only | To show names and results on the screen | Gone when the TV app closes |
| Connection data: delay and packet rate | Sent from the phone to the TV. Not saved | To keep play smooth | Discarded |

We do not collect your location, contacts, photos, microphone recordings, advertising ID or device identifiers. The profile ID is random and made on your phone. It is not tied to your phone or to you.

## 3. What is sent over your Wi-Fi

The TV sends nothing on your network by itself. A phone finds the TV when you type the room code that the TV shows, or scan the QR code on the TV. The room code stands for the address of the TV on your Wi-Fi network: the phone builds that address from its own Wi-Fi address and the code, and tries to connect to it (one try for each Wi-Fi address of the phone). The phone then connects directly to the TV and sends your profile name, avatar and ID, the motion readings and the button presses. A device that has the address of a wrong guess gets a connection attempt and nothing else.

There is no PIN or password: anyone on the same network who knows the room code or sees the QR code on the TV can join the game.

**This traffic is not encrypted.** A device that can read the traffic between a phone and the TV on your network can read it. Play only on a network you trust, and do not play on public Wi-Fi.

The apps themselves send nothing outside your local network.

## 4. Camera, clipboard and sharing a profile

- **QR code scan (Android).** To scan the QR code of the TV or of a shared profile, the Controller opens the Google code scanner, which is part of Google Play services. The picture of the camera stays on your phone and is not sent to us or to Google. Sababi receives only the text of the code. Google receives technical data about how the scanner works, such as the phone model, the version of the operating system, the version of the app and performance information, and uses it to run and improve the scanner. Google's terms apply to this part: <https://developers.google.com/ml-kit/terms>. A phone without Google Play services cannot scan. It types the room code instead, and then nothing is sent to Google.
- **QR code scan (iPhone and iPad).** To scan the QR code of the TV or of a shared profile, the Controller uses the camera of your iPhone. iOS asks for your permission the first time. The camera picture is shown on the scan screen only while it is open. It stays on your phone: Sababi does not save it and does not send it to us or to anyone else. Sababi receives only the text of the code. If you tap Don't Allow, you can type the room code instead, and you can turn the camera on later in Settings > Sababi.
- **Share a profile.** A profile can be copied to another phone as a QR code or as text. The code holds the profile ID, the name, the avatar and the best scores, with no password. Anyone who scans the QR code or reads the text gets a copy. The QR code is hidden after 60 seconds. If you tap Copy Code, the text goes to the clipboard, where other apps on your phone may be able to read it.
- **Paste.** The Controller reads the clipboard only when you tap Paste a code in the player list, to read a profile code.

## 5. Permissions

Android: internet and network state (to talk to the TV), Wi-Fi state (to keep the connection steady), keep awake (so the screen does not sleep during a game), and vibration (the Controller only). iPhone: local network (to connect to the TV on your network) and camera (only to scan a QR code; you can say no and type the room code instead).

## 6. Sharing and third parties

We do not sell or share personal data, because we do not receive it. The only third-party component that touches your data on the device is Google Play services (the QR scanner, Android only). The QR scanner on the iPhone is part of iOS (Apple's camera framework): it adds no third-party component. If you install the apps from Google Play or from another store, that store collects its own data under its own policy.

## 7. Children

Sababi is a game for family and friends. It is not aimed at children, but children may play it. We collect nothing from children. A profile name stays on the phone and is shown on the TV to the people in the room. Parents should choose a first name or a nickname, not a full name, and should be near when a child plays.

## 8. Your choices

- Edit or delete a profile in the Controller (Who is playing). Deleting removes it from that phone.
- **Disconnect** in the Controller ends the session with the TV and clears its token. The address of the TV stays saved until you uninstall the app or clear its data.
- Uninstall the app or clear its data to remove everything. A copy of a profile that you shared to another phone stays on that phone until it is deleted there.
- We hold no data about you, so there is nothing for us to look up, correct or delete for you. The data is on your devices and under your control.

## 9. Security

Profiles are stored in the private storage of the app and are not encrypted. Network traffic on your Wi-Fi is not encrypted (section 3). Names are limited to letters, digits and spaces, and the TV checks everything it receives.

## 10. Changes

If an update adds a server, an account, analytics, advertising or online play, we will change this notice before the update is released, and show the new date at the top.

## 11. Contact

Alon Yampolski · sababi.play@gmail.com
