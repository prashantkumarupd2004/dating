# 🚨 CRITICAL: 429 ERROR STILL OCCURRING - NEXT STEPS

## UPDATED STATUS

The 429 error is **still occurring** despite our fixes. This means there's an additional source of request flooding that we need to identify.

---

## ✅ FIXES ALREADY APPLIED

1. ✅ Removed recursive retry logic from WalletProvider
2. ✅ Implemented request deduplication in WalletProvider
3. ✅ Added 429 error handling in api_client.dart
4. ✅ Removed redundant fetchBalance() calls from screens
5. ✅ Removed fetchBalance() from splash screen
6. ✅ Added comprehensive API request logging
7. ✅ Created API request counter to track flooding

---

## 🔍 NEW DIAGNOSTIC TOOLS ADDED

### 1. **Enhanced Logging** (`api_client.dart`)
Every API request now logs:
```
🌐 [API Request] GET /api/wallet
❌ [API Error] 429 - GET /api/wallet
⚠️ Rate limited (429) on /api/wallet — retry after 60s
```

### 2. **Request Counter** (`api_request_counter.dart`)
Tracks all requests and warns when flooding occurs:
```
🚨 [API FLOOD WARNING] GET /api/wallet: 15 requests in last minute!
```

### 3. **Request Summary**
Can print detailed summary:
```
📊 [API Request Summary]
   Total requests: 150
   Last 1 min: 45 requests
   By endpoint:
     GET /api/wallet: 30 requests
     GET /api/listeners: 10 requests
```

---

## 🎯 NEXT STEPS TO IDENTIFY THE REAL CULPRIT

### Step 1: Install the New APK with Logging

Build and install the updated APK (with all the logging):

```bash
cd mobile
flutter build apk --release
```

### Step 2: Run with ADB Logging

Connect your phone via USB and run:

```bash
adb logcat | grep -E "🌐|❌|🚨|⚠️"
```

This will show:
- Every API request being made
- Any 429 errors
- Flood warnings when too many requests

### Step 3: Monitor for 5 Minutes

Watch the log output for 5 minutes and look for:

1. **Which endpoint is causing 429?**
   - `/api/wallet`?
   - `/api/listeners/me`?
   - `/api/listeners`?
   - Something else?

2. **How many requests per minute?**
   - Count the requests to the flooded endpoint

3. **When does flooding start?**
   - Immediately on login?
   - After navigation?
   - After 2-3 minutes?

4. **What triggers the requests?**
   - Screen navigation?
   - Background/foreground?
   - Socket events?
   - Timer?

---

## 🔎 POSSIBLE REMAINING SOURCES

### 1. **Socket Reconnection Loop**
If socket keeps disconnecting and reconnecting, it might trigger API calls.

**Check:** `lib/core/socket/socket_service.dart`
- Line 57-80: `_reconnectWithFreshToken()` method
- Does this create a loop?

### 2. **App Lifecycle Events**
Every time app goes background/foreground, it might trigger requests.

**Check:** `lib/main.dart`
- Line 61-72: `didChangeAppLifecycleState()`
- Does `sessionManager.refreshSession()` cause floods?

### 3. **Listener Status Polling**
Both splash screen and main screen check listener status.

**Already checked:**
- Splash screen: Once on startup (OK)
- Main screen: Once on init (OK)

### 4. **Widget Rebuilds**
If widgets rebuild frequently, they might trigger requests.

**Check:** Do any screens call API in `build()` method?

### 5. **401 Retry Storm**
If token expires and multiple requests get 401, they all retry.

**Already handled:** Single-flight token refresh with `_isRefreshing` flag

### 6. **Backend Rate Limiting Too Strict**
Maybe backend rate limit is too low (e.g., 5 requests/minute).

**Need to verify:** What is the actual rate limit on backend?

---

## 📝 WHAT TO COLLECT FROM LOGS

When you run the app with logging, collect this information:

### 1. **Request Pattern (First 3 Minutes)**
```
Time    | Endpoint              | Count
--------|----------------------|-------
0:00-1:00 | GET /api/wallet      | X requests
0:00-1:00 | GET /api/listeners/me| X requests
1:00-2:00 | GET /api/wallet      | X requests
2:00-3:00 | GET /api/wallet      | X requests
```

### 2. **First 429 Error Details**
```
Time of first 429: XX:XX
Endpoint: /api/XXXXX
Total requests before 429: XXX
Requests to that endpoint: XXX
```

### 3. **Request Frequency**
```
Requests per minute (average): XX
Peak requests per minute: XX
Which endpoint has most requests: XXXXX
```

### 4. **Trigger Pattern**
```
What user action triggered flood:
- [ ] App launch
- [ ] Navigation between tabs
- [ ] Background/foreground
- [ ] Making a call
- [ ] Recharge
- [ ] Other: __________
```

---

## 🛠️ IMMEDIATE ACTIONS YOU CAN TAKE

### Option A: Increase Backend Rate Limit (Temporary)

If your backend allows, temporarily increase the rate limit to buy time:

```javascript
// Example for Express.js
rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 100 // increase from 30 to 100 requests per minute
})
```

### Option B: Run Debug Build Locally

Instead of release APK, run debug build to see all logs:

```bash
flutter run
```

Then navigate the app and watch Android Studio/VS Code logs.

### Option C: Add Request Delay (Temporary Workaround)

Add a small delay to ALL requests (not recommended but can help):

```dart
// In api_client.dart onRequest
await Future.delayed(const Duration(milliseconds: 100));
```

This slows down requests but won't fix the root cause.

---

## 📊 LIKELY SCENARIOS

Based on the patterns, here are the most likely culprits:

### Scenario 1: Socket Reconnection Loop (70% probability)
- Socket disconnects
- Triggers `_reconnectWithFreshToken()`
- Gets new token
- Connects
- Disconnects again
- **Loop creates API flood**

**Solution:** Add reconnection limit, exponential backoff

### Scenario 2: Widget Rebuild Storm (20% probability)
- Some widget rebuilds frequently
- Each rebuild triggers API call
- Creates request flood

**Solution:** Move API calls out of build(), use proper state management

### Scenario 3: Backend Rate Limit Too Strict (10% probability)
- App makes reasonable requests (10-20/min)
- Backend rate limit is very strict (5-10/min)
- Normal usage triggers 429

**Solution:** Increase backend rate limit

---

## ✅ ACTION PLAN

### Immediate (Today):
1. ✅ Rebuild APK with new logging
2. ⏳ Install and run with ADB logging
3. ⏳ Collect log data for 5 minutes
4. ⏳ Identify exact endpoint and pattern

### Next (After Log Analysis):
5. ⏳ Share log data
6. ⏳ Identify root cause from logs
7. ⏳ Apply targeted fix
8. ⏳ Test again

---

## 📞 NEED HELP?

Share these logs with me:
1. ADB logcat output (first 5 minutes)
2. When 429 occurs
3. What you were doing when it happened
4. How many requests per minute

---

**Current Status:** 🔄 Awaiting log data to identify exact source of flooding

**Next Build:** Ready - includes comprehensive logging and request tracking
