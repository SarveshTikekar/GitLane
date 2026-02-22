# 🎬 GitLane Pitch & Demo Script

To flawlessly demonstrate GitLane’s USPs to the judges, **do not use a real production codebase**. Create a throwaway repository on GitHub specifically for this demo to avoid any stress.

Here is your exact, step-by-step script to verify and present each USP.

---

### Step 0: The Setup (Before the Demo)
1. Go to GitHub.com on your laptop. 
2. Create a new public repository called `gitlane-demo`.
3. Add a simple `README.md` and a file called `main.py` with some basic code:
   ```python
   def calculate_totals():
       return "Sum"
   ```
4. Open **GitLane** on your emulator/phone, tap the **+** button on the Home Dashboard, and **Clone** this repository using its HTTPS URL (e.g., `https://github.com/YourName/gitlane-demo.git`).

---

### 🎙️ USP 1: The Native IDE Experience (Semantic Search & Analytics)
*The Pitch:* "GitHub mobile lets you scroll code. We let you *understand* it."

**How to demo it:**
1. Open your cloned `gitlane-demo` repository in GitLane.
2. Go to the **Semantic Search** tab (the magnifying glass icon on the bottom nav).
3. Search for `calculate_totals`.
4. Tap the result. Show the judges how it jumps instantly to the definition of the function using AST (Abstract Syntax Tree) logic, not just dumb text matching.
5. Next, open the **Analytics Dashboard** (from the Tools menu). Show them the graphs—this proves GitLane locally parsed the `.git` folder to calculate commit frequencies without asking a remote server.

---

### 🎙️ USP 2: Enterprise Security (GPG Signing on Mobile)
*The Pitch:* "Making a commit on your phone usually means it's unverified. We brought cryptographic signing to mobile."

**How to demo it:**
1. Go to the **Security Workbench** (Shield icon in Tools).
2. Tap **Generate New GPG Key**. Enter a test name and email.
3. Once generated, go back to the repository and edit `main.py` (change "Sum" to "Total Sum").
4. Go to the **Commit Screen**. 
5. Under the commit message field, **toggle the GPG switch on**.
6. Hit Commit. 
7. *The Flex:* Push the code, open GitHub.com on your laptop, and show the judges the green **"Verified"** badge next to the commit you just made from your phone.

---

### 🎙️ USP 3: The 3-Pane Visual Merge Editor
*The Pitch:* "Merge conflicts usually force developers back to their laptops. We fixed that for touch screens."

**How to demo it:**
*(Requires 1 minute of prep before showing judges)*
1. On your **laptop**, edit `main.py` directly on GitHub.com. Change the code to:
   ```python
   def calculate_totals():
       return "Laptop Sum"
   ```
   Commit this straight to `main`.
2. On **GitLane (mobile)** *before pulling*, edit the exact same line in `main.py` to:
   ```python
   def calculate_totals():
       return "Mobile Sum"
   ```
3. Commit the change on GitLane.
4. Now, press **Pull** in GitLane. It will fail with a Merge Conflict!
5. **Show the Judges:** Tap the **Resolve Conflicts** banner.
6. The app opens the **3-Pane Visual Merge Editor**. Show them the Red (Incoming) and Green (Current) blocks. Tap **"Accept Incoming"** using the mobile UI, then save. You just resolved a conflict on a phone!

---

### 🎙️ USP 4: Advanced Git Terminal
*The Pitch:* "For power users, UI isn't always enough. We compiled bash and libgit2 directly into the app."

**How to demo it:**
1. Open the **Native Terminal** (Tools -> Git Terminal).
2. Type `git log --oneline` and press Enter. 
3. Show the judges the instant bash-style output. 
4. Type `git remote -v`.
5. Point out that this is not an API call to a server—this is a true Unix-style subprocess running a C-compiled Git binary inside the Android sandbox.

---

### 🎙️ USP 5: Quantum Mesh (Offline P2P Collaboration)
*The Pitch:* "What if GitHub goes down? Or what if you're on a plane with no internet? GitLane becomes the server."

**How to demo it (Requires 2 devices connected to the same Wi-Fi, e.g., Emulator + Physical Android):**
1. On **Phone A** (Host), open the repository and tap **Quantum Hub**.
2. Toggle "Host Local Mesh". 
3. Tap the repository name to generate the **QR Code**. 
4. On **Phone B** (Client), go to the Home Dashboard and tap the **QR Scanner** floating button. 
5. Scan Phone A's screen.
6. Phone A will show Phone B popping up under "Peer Management". The Host assigns them "Read" or "Write" access.
7. Phone B instantly downloads the entire repository as a ZIP over local Wi-Fi, completely bypassing the internet. 

---
### 🏁 Final Tip for the Pitch
Keep the pace fast. You don't need to show them every single file edit. 
**1. Scan the QR (Mesh) -> 2. Resolve a Conflict (Merge Editor) -> 3. Show the Verified Badge (GPG).**
If you nail those three, you win.
