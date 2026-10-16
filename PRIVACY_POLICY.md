# Cecy Privacy Policy

> Mirror of the published policy at https://thabo.xyz/cecy/privacy. The published page is authoritative; keep this file in sync with it.

**Effective date:** October 16, 2026
**Last updated:** October 16, 2026

---

## The short version

- **Your cycle records stay on your iPhone.** Periods, symptoms, daily answers, notes, sexual activity, medications, life stages, and biomarkers are stored only on your device. We do not have a copy.
- **No ads, no selling, no tracking.** We don't sell or rent your data, show ads, or include advertising, analytics, or tracking tools in the app.
- **AI insights are optional and off until you turn them on.** If you turn them on, Cecy sends a limited, specific set of facts for each request. It never sends your name, dates, notes, sexual activity, or Apple Health details.
- **Sign in with Apple links an account, but it is not a backup.** We never ask Apple for your email address or name.
- **You're in control.** You can export your records, turn AI off, or delete everything at any time from Settings.

---

## 1. Who we are

Cecy is provided by **Thabo LLC** ("we", "us").

Questions about this policy or your data: **support@thabo.xyz**

## 2. Information stored only on your device

Cecy is designed to work without sending your health records anywhere. The following stay on your iPhone, in Cecy's private storage:

- Period start and end dates, flow, and notes
- Daily bleeding answers (including "not sure")
- Symptoms and their ratings
- Sexual activity records
- Medications, contraception, and whether you took them
- Cycle factors (for example illness, travel, or pregnancy)
- Life stages (cycle change, postpartum, breastfeeding), postpartum bleeding records, and feeding context
- Biomarker records (for example basal body temperature, LH and pregnancy test results, cervical mucus, resting heart rate, sleep)
- Your profile answers (for example preferred name, date of birth, height, weight, cycle length, gender identity, wellness preferences)
- Your feedback on insights (helpful / not helpful)
- Reminder and privacy settings

**How it's protected:**

- Stored using iOS Data Protection ("Complete" protection), so it can't be read while your device is locked.
- Excluded from iCloud and device backups.
- You can add an app lock using Face ID, Touch ID, or your device passcode.

**What this means for you:** because we don't keep a copy and your records are not included in backups, **if you lose, reset, or replace your phone, your records cannot be recovered by us.** Use **Settings → Privacy and export** to save a copy, and keep exported files somewhere secure.

## 3. Information that leaves your device

Cecy sends information off your device in only these cases. Each one is described in full.

### 3.1 Sign in with Apple

Cecy uses Sign in with Apple to link your device to an account.

- **We do not request your email address or name from Apple.** Your preferred name comes from what you type in Cecy.
- Apple gives Cecy an anonymous user identifier. That identifier, plus the link between it and your local profile, is stored securely on your device.
- **Signing in does not back up or restore your records.**

Apple's handling of Sign in with Apple is covered by Apple's privacy policy.

### 3.2 Account registry

When you link your account, Cecy registers that an account is active. We receive only:

- A **one-way (SHA-256) hash** of your Apple user identifier. We never receive the identifier itself.
- A **display name**: your preferred name (up to 100 characters), or "Cecy User" if you didn't enter one. Cecy never sends anything that looks like an email address as a name.
- An account status.

No health records are sent to the registry. When you delete your data in Cecy, our server **permanently deletes** your registry entry (the hash, display name, and status).

### 3.3 AI insights (optional)

AI features are **off by default**. They run only after you turn them on in Settings and accept a notice. Cecy records which version of the notice you accepted, and you can turn AI off at any time.

When you use an AI feature, Cecy sends **only the facts that request needs**:

| Feature | What is sent |
|---|---|
| Describe symptoms in your own words | The text you type |
| Explain an observation | The type of observation, the measurement it's based on, its evidence level, and a standard caution |
| Cycle summary | Cycle and period lengths, average cycle length, common symptom types, and short written observations |
| Ask a question about your cycle | Your question (up to 100 characters) and a description of what the answer may cover |
| Wellness suggestions and daily insights | Estimated cycle day and phase (with its limitations), today's symptoms and severity, today's bleeding answer and flow, and your activity level, preferred exercise, diet, food allergies, and wellness goals |

**Never sent to AI:** your name, date of birth, gender identity, height or weight, calendar dates, private notes, sexual activity, medications, life stages, biomarkers, Apple Health details, or record identifiers.

**Where it goes:** requests go to Cecy's AI service, hosted on **Microsoft Azure in the United States (West US 3)**, which sends them to **OpenAI** to generate responses. OpenAI is a separate company that processes these requests under its own API data policies.

**Retention:** Cecy's AI service does not store your requests or the responses, and its logs record only the type of request, whether it succeeded, and how long it took. OpenAI does not use data sent through its API to train its models. OpenAI may keep API requests for a limited time (up to 30 days) to monitor for abuse, then deletes them.

**Results:** today's daily insights are saved on your device until the day ends, then deleted.

AI responses are general wellness information. They are not medical advice, a diagnosis, or contraception.

### 3.4 Apple Health (optional, read-only)

If you choose to review Apple Health, Cecy asks permission to **read menstrual-flow samples**. You confirm each period start before Cecy saves it on your device. Cecy **does not write** to Apple Health. Health data is never sent to Cecy's servers or to AI, and is never used for advertising or sold.

### 3.5 Contacting support

**Contact support** opens an email in your own email app. Cecy does not add any health records, personal details, or diagnostic information; you review the message before sending. Your email is handled by your email provider and by us to answer your question. Please don't include sensitive health information.

### 3.6 Exports and reports you share

When you export your records (JSON) or create an appointment report (text, CSV, or PDF), Cecy creates the file on your device and **you** decide where it goes. Notes and sexual activity are included only if you choose. Exported files are **not encrypted**. Once shared, they are no longer under Cecy's control.

### 3.7 Reminders

Reminders are scheduled locally on your device. By default, lock-screen notifications are discreet and don't show health details unless you turn that on.

## 4. What we don't do

- We don't sell, rent, or share your personal information for advertising.
- We don't include advertising, analytics, or tracking tools (SDKs) in the app.
- We don't track you across other apps or websites.
- We don't use your health information to make decisions about you, such as for insurance or credit.

## 5. How we use the limited information we receive

- **Registry hash and display name:** to know an account is active. They are permanently deleted when you delete your data.
- **AI request content:** only to generate the response you asked for. It is not used for any other purpose, including training AI models.
- **Support emails:** to respond to you.

## 6. Your choices and rights

- **Turn AI off:** Settings → Privacy. Future requests stop immediately.
- **Export your data:** Settings → Privacy and export.
- **Delete everything:** Settings → Privacy and export → Delete all. This removes your records from the device, removes the local account link, and permanently deletes your registry entry from our server.
- **Apple Health access:** change it any time in the iOS Settings or Health app.
- **Sign in with Apple:** you can stop using Sign in with Apple for Cecy in your Apple Account settings.

Depending on where you live, you may have rights to access, correct, delete, or move your personal information, or to object to or limit how it's used. Because your records are stored only on your device, you can exercise most of these yourself in the app. For anything held on our side (the registry entry or support emails), email **support@thabo.xyz**. We check for and answer requests daily.

## 7. Children

Cecy is not directed to children under 13, and we don't knowingly collect their information. If you believe a child has used Cecy and contacted us, email support@thabo.xyz.

## 8. Security

On-device data uses iOS Data Protection, is excluded from backups, and can be protected with an app lock. Connections to Cecy's services use HTTPS and do not follow redirects. No system is perfectly secure. Please keep your device passcode private and store exported files safely.

## 9. International transfers

Cecy's AI and registry services are hosted in the United States. If you use them from another country, the limited information described in section 3 is transferred to the United States.

## 10. Changes to this policy

If we change how Cecy handles your information, we'll update this policy and the "Last updated" date. If a change affects AI processing, Cecy will ask you to review and accept the updated notice before sending further AI requests.

## 11. Contact

**Thabo LLC**
Email: **support@thabo.xyz**

© 2026
