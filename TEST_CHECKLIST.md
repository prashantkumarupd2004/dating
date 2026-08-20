# Background Audio Fix - Test Checklist

## Pre-Test Setup
- [ ] Install the debug APK on a physical Android device
- [ ] Grant microphone and camera permissions
- [ ] Grant notification permissions
- [ ] Ensure you have two devices (caller + listener) or one device + web listener

## Test Scenarios

### 1. Caller Backgrounds App
- [ ] Start an audio call as user (caller)
- [ ] Wait for listener to answer
- [ ] Press home button (app goes to background)
- [ ] **Expected**: Notification shows "Ongoing call - In call with [Listener Name]"
- [ ] **Expected**: Listener can hear caller speaking
- [ ] **Expected**: Caller can hear listener speaking
- [ ] Return to app (tap notification or app icon)
- [ ] **Expected**: Call screen shows, audio continues seamlessly

### 2. Receiver Backgrounds App
- [ ] Answer an incoming call as listener
- [ ] Call connects
- [ ] Press home button (app goes to background)
- [ ] **Expected**: Notification shows "Ongoing call"
- [ ] **Expected**: Caller can hear listener speaking
- [ ] **Expected**: Listener can hear caller speaking
- [ ] Return to app
- [ ] **Expected**: Audio continues

### 3. Both Background
- [ ] During active call, both users press home button
- [ ] **Expected**: Both see notifications
- [ ] **Expected**: Two-way audio works for both
- [ ] Both return to app
- [ ] **Expected**: Call continues normally

### 4. Screen Lock Test
- [ ] Start a call
- [ ] Press power button to lock screen
- [ ] **Expected**: Audio continues (can hear other person)
- [ ] Speak into phone
- [ ] **Expected**: Other person can hear you
- [ ] Unlock screen
- [ ] **Expected**: Call screen visible, audio continues

### 5. App Switching Test
- [ ] During call, open another app (WhatsApp, Chrome, etc.)
- [ ] **Expected**: Call notification visible in notification bar
- [ ] **Expected**: Audio continues
- [ ] Switch back to dating app
- [ ] **Expected**: Call continues

### 6. Back Button Test
- [ ] During active call, press back button
- [ ] **Expected**: Dialog shows "End call?"
- [ ] Tap "Cancel"
- [ ] **Expected**: Call continues
- [ ] Press back button again, tap "End Call"
- [ ] **Expected**: Call ends gracefully

### 7. End Call Cleanup Test
- [ ] Start a call
- [ ] Background the app (notification should show)
- [ ] Return to app
- [ ] Tap "End Call" button
- [ ] **Expected**: Notification disappears
- [ ] **Expected**: Returns to previous screen
- [ ] Check notifications
- [ ] **Expected**: No stale "Ongoing call" notification

### 8. Network Reconnect Test
- [ ] Start a call
- [ ] Background the app
- [ ] Enable airplane mode for 3 seconds
- [ ] Disable airplane mode
- [ ] **Expected**: Agora reconnects automatically
- [ ] **Expected**: Audio resumes after reconnect

### 9. Video Call Background Test
- [ ] Start a video call
- [ ] Wait for connection
- [ ] Press home button
- [ ] **Expected**: Notification shows "Ongoing call" with camera icon
- [ ] **Expected**: Audio continues (video freezes in background is OK)
- [ ] Return to app
- [ ] **Expected**: Video resumes, audio continues

### 10. Remote Hang Up While Backgrounded
- [ ] Start a call as user
- [ ] Background the app
- [ ] Listener ends the call
- [ ] **Expected**: Notification disappears
- [ ] **Expected**: App shows "Call ended" snackbar when reopened
- [ ] **Expected**: Returns to previous screen

## Edge Cases

### Long Background Duration
- [ ] Start a call
- [ ] Background the app for 5+ minutes
- [ ] **Expected**: Call continues throughout
- [ ] Return to app
- [ ] **Expected**: Duration timer shows correct elapsed time

### Multiple Background/Foreground Cycles
- [ ] Start a call
- [ ] Background → Foreground (5 times)
- [ ] **Expected**: Audio works every time
- [ ] **Expected**: No audio glitches or mute issues

### Mute/Speaker Controls in Background
- [ ] Start a call
- [ ] Toggle mute ON
- [ ] Background the app
- [ ] **Expected**: You remain muted
- [ ] Return to app
- [ ] **Expected**: Mute button still shows "ON"
- [ ] Toggle mute OFF
- [ ] **Expected**: Audio resumes

## Regression Tests (Ensure Nothing Broke)

### Existing Features
- [ ] Incoming call notification works
- [ ] Listener dashboard loads
- [ ] Listener earnings screen works
- [ ] User can initiate calls normally
- [ ] Call duration timer counts correctly
- [ ] Rating dialog shows after call ends
- [ ] Wallet balance updates after call

## Performance Checks
- [ ] During background call, open Settings → Apps → Dating App
- [ ] Check battery usage (should be moderate, not excessive)
- [ ] Check memory usage (should be +2-3 MB vs before)
- [ ] Notification should be low-priority (not disturbing)

## Device Variations
Test on at least 2 different devices with:
- [ ] Android 11 or below
- [ ] Android 12+
- [ ] Android 14+ (if available)
- [ ] Different OEMs (Samsung, Xiaomi, OnePlus, etc.)

---

## Known Limitations
- iOS not supported yet (requires CallKit implementation)
- Video pauses when backgrounded (audio continues - this is expected)
- Notification is basic (no call duration or action buttons yet)

## If Tests Fail
1. Check logcat: `adb logcat | grep -i "call\|agora\|foreground"`
2. Verify foreground service starts: Look for notification
3. Check permissions: Settings → Apps → Dating App → Permissions
4. Report exact steps to reproduce + device model + Android version
