# Sababi Privacy Notice

"Sababi: TV Games" and "Sababi: Remote". Last updated: 2026-11-09.
Provider: Alon Yampolski, Israel. Contact: sababi.play@gmail.com

Sababi does not collect your personal data. We run no server, no account system and no analytics, so we never receive your name, your scores or your sensor readings. Everything below describes what stays on your own devices and your own Wi-Fi.

## 1. What the apps are

- **"Sababi: TV Games"** runs on a TV or TV box and shows the games.
- **"Sababi: Remote"** runs on a phone and is the game controller.

The two apps communicate over the Wi-Fi network you are both on. They do not need the internet to play.

## 2. Information the apps handle

| Information | Where it lives | Why | How long |
|-------------|----------------|-----|----------|
| Player profile: a random ID, a name, an avatar and best scores | On the phone, in the private storage of the app | To show your name and avatar on the TV and to keep your best scores | Until you delete the profile, clear the data of the app or uninstall it |
| Last TV you joined: its network address, port, room code and a session token | On the phone | To reconnect after a short break | Until you leave the TV or uninstall |
| Settings: your choices in the apps | On the phone or on the TV, where you changed it | To remember your choices | Until you uninstall or clear data |
| Motion data: accelerometer and gyroscope readings | Sent from the phone to the TV about 60 times a second while you are connected. Not saved | To steer the game | Used at once and discarded |
| Name, avatar and scores of the players in the current game | On the TV, in memory only | To show names and results on the screen | Gone when the TV app closes |

The profile ID is random and made on your phone. It is not tied to your phone or to you.

## 3. What is sent over your Wi-Fi

The TV sends nothing on your network by itself. A phone finds the TV when you type the room code that the TV shows, or scan the QR code on the TV. The room code identifies the TV on your Wi-Fi network. The phone then connects directly to the TV and sends your profile name, avatar and ID, the motion readings and the button presses.

The host can approve or refuse every join request: when a new phone wants to join, the TV shows its name and the host chooses ALLOW or REFUSE with the TV remote.

**This traffic is not encrypted.** A device that can read the traffic between a phone and the TV on your network can read it. Play only on a network you trust, and do not play on public Wi-Fi.

The apps themselves send nothing outside your local network.

## 4. Camera and sharing a profile

- **QR code scan (Android).** To scan the QR code of the TV or of a shared profile, the Controller opens the Google code scanner, which is part of Google Play services. The picture of the camera stays on your phone and is not sent to us or to Google. Sababi receives only the text of the code. Google receives technical data about how the scanner works and uses it to run and improve the scanner. Google's terms apply: <https://developers.google.com/ml-kit/terms>. A phone without Google Play services cannot scan and types the room code instead.
- **Share a profile.** A profile can be copied to another phone as a QR code. The code holds the profile ID, the name, the avatar and the best scores, with no password. Anyone who scans the QR code gets a copy. The QR code is hidden after 60 seconds.

## 5. Permissions

Android: internet and network state (to communicate with the TV), Wi-Fi state (to keep the connection steady), keep awake (so the screen does not sleep during a game), and vibration (the Controller only).

## 6. Sharing and third parties

We do not sell or share personal data. The only third-party component that touches your data on the device is Google Play services (the QR scanner, Android only).

## 7. Children

Sababi is a game for family and friends. A profile name stays on the phone and is shown on the TV to the people in the room. Parents are advised to choose or review the profile name, and to be near when a child plays.

## 8. Your choices

- Edit or delete a profile in the Controller (the pencil next to the player name on the Connect screen). Deleting removes it from that phone.
- **Disconnect** in the Controller ends the session with the TV and clears its token. The address of the TV stays saved until you uninstall the app or clear its data.
- Uninstall the app or clear its data to remove everything. A copy of a profile that you shared to another phone stays on that phone until it is deleted there.

## 9. Security

Profiles are stored in the private storage of the app and are not encrypted. Network traffic on your Wi-Fi is not encrypted (section 3).
