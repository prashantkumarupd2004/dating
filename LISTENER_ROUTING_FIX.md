# Listener Dashboard Routing Fix

## Problem
Approved listeners were seeing the user homepage when reopening the app, instead of being automatically redirected to the listener dashboard.

## Root Cause
The splash screen had listener status check logic, but it was silently failing or not handling all edge cases properly. Additionally, there was no fallback check in the MainScreen if an approved listener accidentally landed on the user home.

## Changes Made

### 1. Splash Screen (`mobile/lib/features/auth/presentation/screens/splash_screen.dart`)
**Improvements:**
- Added debug logs to track listener status detection
- Improved error handling - now explicitly checks `resp.statusCode == 200`
- Added null safety check for `listenerData`
- Restructured logic flow:
  - Not logged in → `/auth/login`
  - Logged in + Approved listener → `/listener/dashboard`
  - Logged in + Pending/Rejected listener → `/home`
  - Logged in + Not a listener → `/home`
- Added detailed debug prints for troubleshooting

### 2. Main Screen (`mobile/lib/features/home/presentation/screens/main_screen.dart`)
**New Feature:**
- Added `initState()` with `_checkListenerStatus()` method
- Automatically checks listener status when MainScreen loads
- If approved listener detected → redirect to `/listener/dashboard`
- Acts as a safety net if splash screen logic fails

### 3. Backend - Auth Service Fix (`backend/src/modules/auth/auth.service.ts`)
**Fixed Login Issues:**
- Fixed `findOrCreateUser()` query logic (was using AND on googleId+email, now uses googleId only)
- Added race condition handling for concurrent new user creation
- Fixed database authentication errors

## How It Works Now

```
App Launch
    ↓
Splash Screen
    ↓
Logged in? ──No──> Login Screen
    ↓ Yes
    ↓
Check /listeners/me API
    ↓
Status = "APPROVED"? ──Yes──> Listener Dashboard ✅
    ↓ No
    ↓
User Home (MainScreen)
    ↓
MainScreen.initState()
    ↓
Re-check listener status
    ↓
Status = "APPROVED"? ──Yes──> Redirect to Listener Dashboard ✅
    ↓ No
    ↓
Stay on User Home
```

## API Endpoint Used
- **Endpoint:** `GET /api/listeners/me`
- **Response:**
```json
{
  "success": true,
  "data": {
    "id": "...",
    "userId": "...",
    "status": "APPROVED", // or "PENDING", "REJECTED"
    "profile": {...},
    ...
  }
}
```

## Testing Checklist
- [ ] Fresh install - approved listener opens app → goes to listener dashboard
- [ ] App backgrounded then reopened → stays on listener dashboard
- [ ] App force-closed then reopened → goes directly to listener dashboard
- [ ] Pending listener → goes to user home
- [ ] Regular user (not a listener) → goes to user home
- [ ] Logout and login again as approved listener → listener dashboard

## Deployment
1. ✅ Backend changes deployed to EC2
2. ⏳ Mobile app APK building (background process)
3. 📦 Once build completes, install APK and test

## Debug Logs
Watch for these logs in Flutter console:
- `🎧 Listener status: APPROVED`
- `✅ Redirecting approved listener to dashboard`
- `✅ Approved listener detected in MainScreen, redirecting to dashboard`
- `⏳ Listener status is PENDING, going to home`
- `❌ Listener check failed: <error>`

---
**Date:** 2026-08-17
**Fixed by:** Claude Code
