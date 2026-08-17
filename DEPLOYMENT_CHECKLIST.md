# Wallet Balance Fix - Deployment Checklist

## ✅ Changes Completed

### Code Changes
- [x] Created centralized `WalletProvider` singleton
- [x] Updated `HomeScreen` to use provider
- [x] Updated `WalletScreen` to use provider  
- [x] Updated `ProfileScreen` to use provider
- [x] Updated `RechargeScreen` for optimistic updates
- [x] Updated `LoginScreen` to initialize balance
- [x] Updated `SplashScreen` to load balance on restart
- [x] Updated `AudioCallScreen` to refresh after calls
- [x] Updated `VideoCallScreen` to refresh after calls

### Testing Checklist
- [ ] Test balance display after fresh login
- [ ] Test balance update after recharge (Razorpay)
- [ ] Test balance update after audio call ends
- [ ] Test balance update after video call ends
- [ ] Test balance persists after app restart
- [ ] Test balance syncs across all tabs (Home/Wallet/Profile)
- [ ] Test multiple recharges in sequence
- [ ] Test multiple calls in sequence
- [ ] Test logout clears balance
- [ ] Test re-login loads fresh balance

## Build Status

### APK Generation
- [x] Flutter clean completed
- [x] Dependencies installed (flutter pub get)
- [ ] Release APK building... (in progress)

### Expected Output
**Location:** `mobile/build/app/outputs/flutter-apk/app-release.apk`

**Build includes:**
- Fixed wallet balance display
- All existing features intact
- No breaking changes
- Optimized release build

## Deployment Notes

### For Testing
1. Install APK on test device
2. Login with Google account
3. Check balance displays correctly
4. Perform test recharge (use Razorpay test mode)
5. Make test call
6. Verify balance updates in real-time

### Backend Requirements
- No backend changes needed ✅
- Existing APIs work as-is ✅
- Socket events compatible ✅

### Rollback Plan
If issues occur, revert these commits:
- `wallet_provider.dart` creation
- All 9 screen modifications

Original balance fetching logic can be restored per-screen.

## Performance Impact
- **Memory:** +1 singleton instance (~minimal)
- **API calls:** Reduced (deduplication logic)
- **UI updates:** More efficient (targeted rebuilds)
- **Battery:** No impact (no polling)

## Known Limitations
- Balance updates require API call (not real-time socket yet)
- 2-second deduplication window (prevents spam)
- Optimistic updates assume success (rare edge case if payment succeeds but verify fails)

## Future Enhancements
- Backend could emit `wallet:balance` socket events after transactions
- Could add pull-to-refresh gesture on balance display
- Could show loading indicator on CoinBadge during fetch
- Could cache balance in secure storage for offline display

---

**Status:** Build in progress...
**Next:** Test APK installation and verify all scenarios
