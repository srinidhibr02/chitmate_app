# ChitMate on Google Play: listing, forms and test plan

Copy the text below into Play Console. Everything here matches what the app does today
(version 1.0). If you add features (member voting from phones, the ₹10 fee), update the
listing, the Data safety form and the privacy policy first.

Graphics are in `store/`: `icon-512.png` and `feature-graphic-1024x500.png`.

---

## 1. Store listing

**App name** (max 30): `ChitMate: Chit Group Tracker`

**Short description** (max 80, 71 used):
`Track your chit group: members, chits, voting, fair draws and payments.`

**Full description** (max 4000):

```
ChitMate helps the organiser of a chit group keep everything in one clear place, so
nothing is lost in WhatsApp messages and notebooks.

ChitMate does not handle real money. It never collects, holds, sends or lends money. It
only keeps the records for your group.

WHAT YOU CAN DO
• Add the people in your group with their mobile numbers
• Create chits that belong to one person or are shared between several
• Set the monthly chit value. Shares are checked so they always add up
• Decide each month's winner by vote, by an agreed manual pick, or by a random draw
• Watch the random draw on a spinning wheel
• See who has paid and who is pending each month
• Get reminders 3 days before a payment is due
• Post updates for the group and keep a full activity history
• Get a warning when one person holds too many votes

BUILT-IN FAIRNESS
• One vote per full chit; people holding only shared chits get one vote
• You can't vote for yourself, and only your first vote counts
• A chit that has won can't win again until the cycle is complete
• Nobody wins two months in a row unless there is no other choice
• Once the cycle starts, the number of chits is locked

YOUR ACCOUNT
• Sign in with your mobile number and a one-time code, and stay signed in
• Your groups are saved to your account, so they are safe if you change phones
• Delete your account and data any time from Settings

Group members can sign in with the same mobile number to see their group.

ChitMate is a record-keeping tool. It is not a chit fund company, bank or payment
service. Money between group members is arranged and paid outside the app.
```

**Category:** Finance (Productivity is also fine for a tracker; Finance is the more accurate
one). **Tags:** pick what Play offers for "Personal finance" / "Budgeting".

**Contact details:** email `zerolpa2022@gmail.com`; website `https://chitmate-e04dd.web.app`;
privacy policy `https://chitmate-e04dd.web.app/privacy.html`. Phone is optional.

**Graphics**
- App icon 512×512: `store/icon-512.png`
- Feature graphic 1024×500: `store/feature-graphic-1024x500.png`
- Phone screenshots: at least 2, ideally 6–8, portrait (for example 1080×1920). Take them from a
  real phone or emulator with a sample group (not real people's names or numbers). Suggested
  order: (1) group list on the home screen, (2) group overview, (3) members and chits,
  (4) the random-draw wheel, (5) result with payouts, (6) payments tab, (7) updates, (8) Settings.
- Optional: 7-inch and 10-inch tablet screenshots (not required to publish).

**Do not write** "guaranteed", "earn", "returns", "loan", "bank approved", "RBI", or
anything suggesting the app pays out money.

---

## 2. App content forms

| Form | Answer |
|---|---|
| Privacy policy | `https://chitmate-e04dd.web.app/privacy.html` |
| App access | "All or some functionality is restricted". Instructions: *Sign in with mobile number 9876543210 (India, +91) and one-time code 123456.* (Keep the Firebase test number active for the reviewers.) |
| Ads | No, the app contains no ads |
| Content rating | Fill the IARC questionnaire honestly: no violence, no sexual content, no profanity, no drug references, no user-to-user chat, no location sharing. The random draw is a fair way to pick a group member and no money is staked, so answer **No** to gambling and simulated gambling. Expect a low rating (for example 3+). |
| Target audience | 18 and over only |
| News app | No |
| Government app | No |
| Health apps | No |
| Data safety | See section 3 |
| Financial features declaration | Say the app does not offer loans, banking, payments, trading or insurance. If the form has an "other financial features" or "tools to track personal finances" option, choose that and describe it as record keeping for a chit group with no money handled. Read each question before answering; a wrong answer can get the app rejected. |
| Account deletion | In-app: Settings → Delete account. Web: `https://chitmate-e04dd.web.app/delete-account.html` |
| Permissions | `INTERNET` (sync), `POST_NOTIFICATIONS` (reminders), `RECEIVE_BOOT_COMPLETED` (restore reminders after a restart). No exact-alarm, contacts, location, SMS, camera or storage permissions. |

---

## 3. Data safety answers

Based on what the app and the Firebase SDKs do. Google's own disclosure for Firebase
(Authentication, Firestore, Installations) is at
https://firebase.google.com/docs/android/play-data-disclosure. Re-check it if you add Firebase
products such as Analytics, Crashlytics or Messaging.

**Does the app collect or share user data?** Yes, collects. **Is all data encrypted in transit?** Yes.
**Can users request deletion?** Yes (in-app and web link above).

| Data type | Collected | Shared with third parties | Optional | Purposes |
|---|---|---|---|---|
| Personal info → **Phone number** | Yes | No (processed by Google/Firebase on our behalf) | Required | Account management, App functionality |
| Personal info → **Name** (organiser's name; member names typed by the organiser) | Yes | No | Required for organisers | App functionality |
| Personal info → **User IDs** (Firebase user ID) | Yes | No | Required | Account management, App functionality |
| Financial info → **Other financial info** (chit value, shares, payment-status marks) | Yes | No | Required to use groups | App functionality |
| App activity → **Other user-generated content** (votes, results, updates, activity log) | Yes | No | Required to use groups | App functionality |
| Device or other IDs (Firebase installation ID, IP address, Play Integrity token used during phone sign-in) | Yes (collected automatically by Firebase) | No | Required | Account management, Security and fraud prevention |

Answer **No** for: location, contacts, photos, files, audio, calendar, web browsing, messages,
health, search history, and "data used for advertising or sold".

Notes:
- Google acts as a service provider for us. Play does not count that as "sharing".
- Other group members can see the group's records. That is part of the feature, not sharing with
  third parties.

---

## 4. Closed testing (required for a new personal developer account)

If your Play developer account was created as a **personal** account after 13 November 2023,
Google requires a closed test with **at least 12 testers opted in for 14 continuous days** before
you can apply for production. Organisation accounts are exempt. Check in Play Console →
Dashboard whether it asks for this.

**Steps**
1. Finish the setup tasks in the Play Console dashboard (listing, forms above).
2. Testing → **Closed testing** → create a track → add testers: create a Google Group, add the
   testers' Gmail addresses (they must be Gmail / Google accounts), and add the group's email
   as the tester list.
3. Upload the `.aab` (`flutter build appbundle --release`, see `RELEASE.md`) and roll it out
   to the closed track. Review by Google can take a few days.
4. Share the opt-in link with testers. They **accept the invite, then install from Play**. They
   must stay opted in for the full 14 days. Recruit 20 or more, since some will drop out.
5. During the 14 days, ask testers to: sign in, create or join a group, add members, create chits,
   run a draw, record payments, and delete a test account. Collect bugs and ideas; fix and push
   new builds to the same track (this keeps the clock running).
6. After 14 days Play Console shows an **Apply for production** button. Describe how you
   recruited testers, what feedback you got and what you changed.
7. Production review usually takes from a few days up to about a week.

**Message to send testers**
> Hi! I'm testing my app ChitMate (a chit group tracker; it doesn't handle money). Please
> install it from this link: <opt-in link>. Sign in with your mobile number, try creating a
> group and a chit, and tell me anything confusing or broken. Please keep it installed for the
> next 14 days. Thank you!

**Each tester needs:** a Gmail address, an Android phone, a mobile number that can receive
an SMS code (real SMS costs a little on your Blaze plan; keep the region list to India).

---

## 5. Before every release

- [ ] `flutter analyze` and `flutter test` pass (`tool/verify.sh`)
- [ ] Version number raised in `pubspec.yaml` (`1.0.0+2`, …)
- [ ] Built with the **upload key** (check `android/key.properties` exists)
- [ ] Play App Signing SHA-1/SHA-256 and upload-key SHA-1/SHA-256 are in the Firebase Android app
- [ ] Firestore rules deployed (`firebase deploy --only firestore`)
- [ ] Privacy and deletion pages deployed (`firebase deploy --only hosting`) and opening
- [ ] Tried on a real phone: login, create group, draw, delete account
- [ ] Firebase test number still active for reviewers
- [ ] Release notes written (for example: "First release of ChitMate.")
