# Client discovery: Batch 1 (50 questions)

Use these with the person who asked you to build the app. Each batch can map to a **new version** once you have the answers. Questions are based on what is **already implemented** so the client can say how they want it to behave.

---

## Strategy: what you’re doing

- **50 batches** = 50 rounds of questions → 50 versions (or you group answers into fewer releases).
- **Questions from current features** = clear, concrete (“when admin rejects, should the user get a notification?”) instead of vague (“do you want notifications?”).
- **Step by step** = you avoid building the wrong thing and you get a written record of decisions.

**Recommendation:**  
- **5 batches first** is smart. It’s easier to get answers and to deliver. You can always add more batches later.  
- **50 batches** is a lot of back-and-forth; consider doing 5–10 “discovery batches” and then grouping answers into 5–10 **releases**, not 50 separate versions.

---

## Other ways to understand what the client wants

1. **User stories / jobs**  
   “When a parent opens the app, what’s the one thing they must do this week?”  
   “When the admin opens it on Monday morning, what’s the first thing they do?”  
   You get priorities and flows, not just yes/no.

2. **Walk the existing app**  
   Share the app (or screens) and ask: “When you’re here, what would you expect to happen if you tap this?”  
   “What’s missing on this screen for your daily use?”

3. **Edge cases and rules**  
   “If a player already has 3 approved slots and one gets rejected, can they choose a new 4th slot or do they stay at 2 until next week?”  
   “Can a player change their 3 choices after submitting but before admin approves?”

4. **One sentence per role**  
   “In one sentence, what does the **player** use the app for?” Same for **admin**, **coach**, **parent**.  
   Aligns everyone on the main goal per role.

5. **Wishlist vs must-have**  
   For each feature: “Is this must-have for v1 or can it be later?”  
   Helps you scope the next version.

6. **Competitor / reference**  
   “Is there another app or academy (even on paper) that does something close to what you want?”  
   Gives a reference for UX and features.

---

## 50 questions – Batch 1 (from current implementation)

### Admin: approving / rejecting slot requests

1. When the admin **rejects** a player’s slot request, should the player get a **notification** that their request was denied?
2. When a request is rejected, should the player be able to **choose 3 slots again** (same week), or do they wait until the next week?
3. When the admin **approves** a request, should the player get a notification that their slot was approved?
4. Should the admin be able to add a **reason or note** when rejecting (e.g. “Court full”) that the player can see?
5. Should the admin see **only pending** requests, or also approved/rejected with a filter or tabs?

### Player: 3 slots per week

6. Right now a player picks **exactly 3 slots** per week. Should it stay “exactly 3” or can it be “up to 3” (e.g. 1 or 2 allowed)?
7. After the player submits their 3 choices, can they **change** them before the admin approves, or is it final once submitted?
8. If the player has **1 approved** and **2 pending**, can they add another pending slot or do they have to wait for the 2 pending to be approved/rejected?
9. Should the player see a **history** of their past weeks (approved/rejected), or only the current week?
10. Should there be a **deadline** (e.g. “Submit by Sunday 8pm for next week”) and should the app show it to the player?

### Schedules (admin creates, player sees)

11. Admin creates schedules with **recurring weekdays**. Should players see schedules for **one week at a time** (current behavior) or for the **whole month**?
12. When the admin **deletes** a schedule that players have already registered for, should those registrations be cancelled and the players notified?
13. Should the admin be able to **copy** last week’s schedules to this week instead of re-entering everything?
14. Maximum **4 players per slot** is enforced. Should this number be **configurable** (e.g. 3 or 5) or always 4?
15. Should the same slot (court + time + level) be allowed on **multiple weekdays** (e.g. Mon and Wed 4–5pm), or is that already how you want it?

### Levels and age

16. When a player has **no age** set, we show all levels. Should we **encourage** them to set their age (e.g. banner or prompt) or leave it optional?
17. If a player **changes their level** in profile, should their **existing approved slots** stay as-is, or should they be re-checked (e.g. only for that level)?
18. Should **parents** see a different set of levels or the same as players?
19. Should the app **recommend** levels based on age (e.g. “For your age we recommend Red/Orange”) or only filter which levels are shown?
20. Can a player have **no level** (null) and still book slots, or must they choose a level before they can pick slots?

### Notifications

21. We have notification types like `booking_approved`, `booking_rejected`, `session_cancelled`. Should **slot approved/rejected** use these same types or new ones (e.g. `slot_approved`, `slot_rejected`)?
22. When the player gets a notification, should tapping it **open a specific screen** (e.g. Home or Schedule) or just the notifications list?
23. Should **admins** get notifications (e.g. “New slot request from [name]”) when a player submits their 3 choices?
24. Should notifications be **push** (phone notification when app is closed) or only **in-app** for now?
25. Should the player be able to **turn off** certain notification types (e.g. only announcements, no booking updates)?

### Player home and registration screen

26. On the Home “pick 3 slots” screen, should **full** slots (4/4 players) be **greyed out** or hidden so the player can’t tap them?
27. Should the player see **who else** is in each slot (names or “3 others”) or only “X/4 players”?
28. When the player has already submitted 3 slots, should they see a **“Change my choices”** button (if you allow changes) or only “View my slots”?
29. Should the week navigation (previous/next week) have a **limit** (e.g. only current week + next 2 weeks) or allow any future week?
30. Should we show a **summary** before submit (e.g. “You chose: Mon 4–5pm Court 1, Wed 5–6pm Court 2, Fri 3–4pm Court 1”)?

### Admin: schedules and courts

31. Should the admin be able to **name** courts (e.g. “Court A”, “Main”) instead of only numbers 1–4?
32. When adding a schedule, should the admin set a **default max players** per slot (e.g. 4) or keep it global for all slots?
33. Should schedules have an **end date** (e.g. “Until end of term”) or can they run indefinitely until the admin removes them?
34. Should the admin see **how many players** are pending/approved per slot when viewing schedules?
35. Should the admin be able to **bulk approve** (e.g. “Approve all for this week”) or only one by one?

### Admin: registrations list

36. In the registrations list, should the admin see the player’s **phone** or **email** to contact them if needed?
37. Should the list be **filterable** by day, court, or level?
38. Should **rejected** requests stay in the list (with a “Rejected” label) or disappear from the main view?
39. Should the admin be able to **undo** an approval or rejection (e.g. back to pending)?
40. Should the admin see **when** the player submitted (e.g. “2 hours ago”) to prioritize?

### Profile and account

41. Should the player be able to **edit** their name and phone in the app, or is that only for admin/signup?
42. Should **parents** have a separate profile (e.g. “Parent of [child]”) and see their child’s slots, or is parent the same as player for now?
43. After **sign up**, should the player be forced to **choose level** before seeing Home, or can they see Home and choose level later?
44. Should we show **subscription** or “membership” status on the profile (e.g. “Active until Dec 2025”) or is that for a later version?
45. Should **coaches** see a different profile (e.g. their sessions, attendance) or the same as players?

### General / UX

46. Should the app support **Arabic** (RTL) everywhere we have text, or only on certain screens?
47. Should there be a **logout** in a clear place (e.g. Profile or More) for all roles?
48. When the app is **offline**, should we show a message (“No connection”) and block actions, or allow some cached view?
49. Should **explore / demo mode** (try as admin/player without account) stay for testing, or be removed in the final app?
50. For **Batch 2**, what is the **one feature or flow** the client wants next (e.g. payments, attendance, coach assignment)? Write their answer here: _______________

---

## How to use this

- Send or ask **5–10 questions per meeting** so it doesn’t feel like a form.
- Write the client’s answers in a simple table (Question # | Answer | Notes).
- Use answers to update the app and to define the next batch of questions.
- Keep **Batch 2** focused on the “one thing next” they chose in Q50.
