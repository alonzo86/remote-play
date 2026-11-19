# Closed test (Google Play)

Google asks a new personal account for a closed test of each app before it opens production: usually 12 or more testers who stay opted in for 14 days (read the Production page of each app in the Play Console for the numbers of today; the rule can change). This file has the message for the testers, the feedback channel and the checklist of the owner for those days. The owner sends the message and reads the feedback; Claude turns each report into an issue (see "Feedback channel").

The two apps are two tests: the TV app "Sababi: TV Games" and the phone app "Sababi: Remote". A tester needs both, so each tester gets both opt-in links.

## The message for the testers (English)

Replace `<TV link>` and `<phone link>` with the two opt-in links of the closed testing tracks (Play Console, each app, Testing, Closed testing, Testers, "Copy link").

> **Test Sababi, a party game for the family and friends**
>
> Sababi is a game for your Android TV. Your phone is the controller: you tilt it, point it and swing it. You need an Android phone and an Android TV (or Google TV), on the same Wi-Fi. Thank you for testing it!
>
> **1. Join the test (about 5 minutes)**
> 1. Use the Google account that you gave me (the one on your phone and your TV).
> 2. On your phone, open this link and tap **Become a tester** (the button can be in Hebrew on a Hebrew phone): `<phone link>`. Then tap **Download it on Google Play** and install **Sababi: Remote**. (Once you are a tester you can also open `https://play.google.com/store/apps/details?id=io.github.alonzo86.sababi.controller` on your phone and install from there.)
> 3. On your phone or your computer, open this link with the same account and tap **Become a tester**: `<TV link>`.
> 4. On your TV, open the **Google Play Store**, search for **Sababi: TV Games** and install it. (Or open `https://play.google.com/store/apps/details?id=io.github.alonzo86.sababi.tv` on your phone and choose your TV in the list of devices.) It can take a few minutes until the app is offered. If the app shows a blank tile on the home screen, restart the TV once.
>
> **2. Please keep both apps installed and stay in the test for 14 days.** Do not leave the test and do not remove the tester link. You can play whenever you like.
>
> **3. Try these (any order, about 20 minutes)**
> - Open the TV app. Open Sababi: Remote on your phone and join the room: scan the QR code on the TV, or type the room code.
> - Play at least 3 games. Try one where you tilt the phone and one where you point it at the screen.
> - Join with a second phone (a friend or family member) and play together.
> - Pause a game and end it from the phone (the pause button) and from the TV remote (Back).
> - Change the language between English and Hebrew and look at both: on the TV (the gear icon on the Games screen, then Language) and on the phone (the Settings icon in the top row of the waiting screen, then Language). Each device has its own language.
> - Make a player on the phone (a name and a picture), join with it, and then join as a guest.
> - Close the phone app in the middle of a game and open it again. Turn the Wi-Fi of the phone off and on.
>
> **4. Tell me what you see** (the good and the bad). Any of these is fine:
> - Write to **sababi.play@gmail.com** (no account needed). Say which app (TV or phone), what you did, what happened and what you expected. A photo or a short video helps (by email only).
> - Or open a form on GitHub: `https://github.com/alonzo86/remote-play/issues/new?template=tester-feedback.yml` (needs a GitHub account; the form is public and your GitHub name shows, so please do not write personal details in it, and do not add photos or videos that show people or children).
>
> Thank you!

## The message for the testers (Hebrew, a draft for the owner to read)

The verbs are in the plural imperative, as in the app. The names of the Play buttons are written in English, because the Play Store shows them in the language of the phone of each tester.

> **בדיקת Sababi, משחק מסיבה למשפחה ולחברים**
>
> Sababi הוא משחק לטלוויזיה עם אנדרואיד. הטלפון הוא השלט: מטים אותו, מכוונים אותו ומניפים אותו. צריך טלפון אנדרואיד וטלוויזיה עם אנדרואיד (או Google TV) באותה רשת אלחוטית. תודה שאתם עוזרים לבדוק!
>
> **1. הצטרפו לבדיקה (כ־5 דקות)**
> 1. השתמשו בחשבון Google ששלחתם לי (זה שבטלפון ובטלוויזיה).
> 2. בטלפון פתחו את הקישור ולחצו על **Become a tester** (בטלפון בעברית הכפתור מופיע בעברית): `<phone link>`. אחר כך לחצו על **Download it on Google Play** והתקינו את **Sababi: Remote**. (אחרי שהפכתם לבודקים אפשר גם לפתוח בטלפון את `https://play.google.com/store/apps/details?id=io.github.alonzo86.sababi.controller` ולהתקין משם.)
> 3. בטלפון או במחשב, עם אותו חשבון, פתחו את הקישור ולחצו על **Become a tester**: `<TV link>`.
> 4. בטלוויזיה פתחו את **חנות Google Play**, חפשו **Sababi: TV Games** והתקינו. (אפשר גם לפתוח בטלפון את `https://play.google.com/store/apps/details?id=io.github.alonzo86.sababi.tv` ולבחור את הטלוויזיה ברשימת המכשירים.) לפעמים לוקח כמה דקות עד שהאפליקציה מוצעת. אם במסך הבית מופיע אריח ריק, הפעילו מחדש את הטלוויזיה פעם אחת.
>
> **2. השאירו את שתי האפליקציות מותקנות והישארו בבדיקה 14 ימים.** אל תעזבו את הבדיקה ואל תסירו את קישור הבודק. אפשר לשחק מתי שרוצים.
>
> **3. נסו (בכל סדר, כ־20 דקות)**
> - פתחו את אפליקציית הטלוויזיה. פתחו את Sababi: Remote בטלפון והצטרפו לחדר: סרקו את קוד ה־QR בטלוויזיה או הקלידו את קוד החדר.
> - שחקו לפחות 3 משחקים: אחד שבו מטים את הטלפון ואחד שבו מכוונים אותו אל המסך.
> - הצטרפו עם טלפון שני (חבר או בן משפחה) ושחקו יחד.
> - עצרו משחק וסיימו אותו מהטלפון (כפתור העצירה) ומשלט הטלוויזיה (חזרה).
> - החליפו שפה בין אנגלית לעברית והסתכלו על שתיהן: בטלוויזיה (סמל גלגל השיניים במסך המשחקים, ואז השפה) ובטלפון (סמל ההגדרות בשורה העליונה של מסך ההמתנה, ואז השפה). לכל מכשיר יש שפה משלו.
> - צרו שחקן בטלפון (שם ותמונה), הצטרפו איתו, ואחר כך הצטרפו כאורח.
> - סגרו את אפליקציית הטלפון באמצע משחק ופתחו אותה שוב. כבו והדליקו את ה־Wi-Fi של הטלפון.
>
> **4. ספרו לי מה ראיתם** (הטוב והרע). בכל דרך:
> - כתבו ל־**sababi.play@gmail.com** (בלי חשבון). כתבו באיזו אפליקציה (טלוויזיה או טלפון), מה עשיתם, מה קרה ומה ציפיתם. תמונה או סרטון קצר עוזרים (רק במייל).
> - או מלאו טופס ב־GitHub: `https://github.com/alonzo86/remote-play/issues/new?template=tester-feedback.yml` (צריך חשבון GitHub; הטופס פומבי ושם המשתמש שלכם ב־GitHub מוצג, לכן אל תכתבו בו פרטים אישיים ואל תצרפו תמונות או סרטונים שרואים בהם אנשים או ילדים).
>
> תודה!

## The store addresses

The two public addresses are the ones of the website (`site/stores.js`): `https://play.google.com/store/apps/details?id=io.github.alonzo86.sababi.controller` (phone) and `https://play.google.com/store/apps/details?id=io.github.alonzo86.sababi.tv` (TV). The owner checked on 2026-11-19 that both open for a tester account. For everybody else they answer "not found" until the apps are in production (issue #427), so the message sends the testers to the opt-in links first and names these addresses only as the place to install from.

## Feedback channel

- **Email (the main way, no account):** `sababi.play@gmail.com`, the contact of the store listing, the website and the privacy notice. The owner reads it and passes each report to Claude in a chat message (the text of the mail, the device and the app).
- **GitHub form (optional):** `.github/ISSUE_TEMPLATE/tester-feedback.yml` ("Tester feedback"). It asks the app (TV, phone or both), the device (TV model and phone model, Android version), the steps, what happened, what the tester expected, and a photo or video. It adds the label `tester-feedback`: create that label once in the repository (Issues, Labels) so the form can set it. The repository is public: a tester must not write personal details in a form.
- **Triage (Claude):** every report that describes a problem or asks for a change becomes a GitHub issue (an existing issue is used when one matches: look in the open issues first). The repository is public, so the issue holds only the app, the device, the steps and the result: never a name, an email address, a photo or a video of a tester, and no quote from the mail that contains one. A bug is fixed in the normal flow (a test that fails before the fix, a pull request, the review). A change of what the user sees (a text, a look) goes to the owner first. A fix goes out in the next version of that app (the version code of an app only goes up; `docs/EXPORT.md`, "The version"). The owner answers each tester who wrote, with thanks.
- **A known thing for testers (the blank tile):** on 2026-11-19 a Sony BRAVIA (Google TV) showed a blank white tile with the package name after a remote install from a phone, until the TV was restarted (issue #384: the installed files were right). It is the launcher of the TV, not the app; the message tells testers to restart the TV once.
- **Do not collect more than needed:** the apps collect nothing, and the test must not change that. Ask testers only for the Google account email (for the tester list in the Play Console), the device model and what they saw.

## Checklist of the owner during the 14 days

1. **Before the start:** create the label `tester-feedback` in the repository once (GitHub, Issues, Labels), so that the form can set it; a closed testing track for each app with a tester list of 12 or more emails (aim for 15 to 20: some testers never opt in); a release in each track (the production bundles: the version codes of `main`, the tags `tv-v<name>-<code>` and `controller-v<name>-<code>`); the countries of the testers; the two opt-in links in the message above.
2. **Send** the message to each tester with the two links. Ask each tester to reply "installed" so that you know who has both apps.
3. **Every few days:** the Play Console shows the number of testers that opted in and the days that are left on the Production page of each app. A tester who left reduces the count: ask for a replacement.
4. **Read the feedback** (email and issues). Do not stop the test for a small problem. A crash or a join that does not work for several testers is worth a new build (a new release in the same track; the 14 days go on).
5. **At the end:** apply for production access in the Play Console of each app. The form asks how you tested and what you changed: use the list of issues that came from the testers. Then submit the production release (the Families policy of the phone app is reviewed by Google).
6. **After the release:** the Google Play links of the website (issue #427).
