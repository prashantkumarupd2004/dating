# 🔍 429 ERROR TROUBLESHOOTING - MANUAL GUIDE

## ✅ CURRENT SITUATION

- App mein 429 error dikh raha hai
- Logs mein error nahi aa raha
- ADB connected hai

---

## 🎯 NEXT STEPS (SIMPLE METHOD)

### Option 1: Complete Logs File Mein Save Karein

```bash
adb logcat > complete_logs.txt
```

**Phir:**
1. App ko 5 minutes use karein
2. Jab 429 error aaye, note kar lein kitne minutes baad aaya
3. Ctrl+C se logging stop karein
4. `complete_logs.txt` file ko editor mein kholen
5. Search karein: "429" ya "DioException" ya "bad response"

---

### Option 2: Real-Time Mein Sirf Errors Dekhen

```bash
adb logcat *:E *:W
```

Yeh sirf Errors aur Warnings dikhayega.

---

### Option 3: Batch Script Use Karein

Maine `collect_logs.bat` file banayi hai. Isse run karein:

```bash
collect_logs.bat
```

Yeh automatically:
1. Logs clear karega
2. Logs collect karega
3. File mein save karega
4. 429 errors ko filter karega

---

## 🔧 AGAR LOGS BILKUL NAHI AA RAHE

Possible reasons:

### 1. Flutter Build Debug Mode Mein Nahi Hai
Release APK mein bahut kam logs aate hain.

**Solution:** Debug APK banayein:
```bash
cd C:\Users\HP\Desktop\Dating App\mobile
flutter build apk --debug
```

### 2. Logcat Buffer Full Ho Gaya
```bash
adb logcat -c  # Clear buffer
adb logcat -G 16M  # Increase buffer size
```

### 3. Wrong Package Name Filter
```bash
# Try without any filter
adb logcat
```

---

## 📊 ALTERNATIVE: APP MEIN HI ERROR DETAILS DEKHEN

Since error app mein dikh raha hai, kya aap screenshot le sakte hain?

**Yeh information chahiye:**
1. Full error message ka screenshot
2. Error kab aaya (how many minutes after login)?
3. Kya kar rahe the jab error aaya?
4. Kaunse screen pe the?

---

## 🚨 IMMEDIATE FIX (Temporary)

Backend rate limit ko increase kar dein temporarily:

**If using Express.js:**
```javascript
rateLimit({
  windowMs: 1 * 60 * 1000,
  max: 100  // increase from 30 to 100
})
```

**If using Nginx:**
```nginx
limit_req_zone $binary_remote_addr zone=api:10m rate=100r/m;
```

---

## 📱 MANUAL OBSERVATION METHOD

Agar logs nahi mil rahe toh manually observe karein:

1. **Fresh install karein**
2. **Timer start karein** (stopwatch)
3. **Normal use karein:**
   - Login: 0:00
   - Home tab: 0:30
   - Wallet tab: 1:00
   - Profile tab: 1:30
   - Call karein: 2:00
   - Call end: 2:30
   - Background: 3:00
   - Resume: 3:30
4. **Note karein:** 429 error exactly kitne minutes:seconds pe aaya
5. **Note karein:** Kya action ke baad aaya

---

Kya aap:
1. `collect_logs.bat` script run kar sakte hain?
2. Ya phir error ka screenshot share kar sakte hain?
3. Ya manually observe karke timing bata sakte hain?
