import 'package:flutter/material.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});
  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  String _status = 'Checking...';
  List<String> _checks = [];

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  Future<void> _runChecks() async {
    setState(() => _checks = []);

    // Check 1: Is logged in?
    try {
      final loggedIn = await SecureStorage.isLoggedIn();
      _addCheck('✓ isLoggedIn: $loggedIn');
    } catch (e) {
      _addCheck('✗ isLoggedIn error: $e');
    }

    // Check 2: Get access token
    try {
      final token = await SecureStorage.getAccessToken();
      _addCheck('✓ Access token: ${token?.substring(0, 20)}...');
    } catch (e) {
      _addCheck('✗ Access token error: $e');
    }

    // Check 3: Profile complete?
    try {
      final complete = await SecureStorage.isProfileComplete();
      _addCheck('✓ Profile complete: $complete');
    } catch (e) {
      _addCheck('✗ Profile complete error: $e');
    }

    // Check 4: Test API call
    try {
      final resp = await api.get(ApiEndpoints.walletBalance);
      _addCheck('✓ API /wallet: ${resp.statusCode}');
    } catch (e) {
      _addCheck('✗ API /wallet error: $e');
    }

    setState(() => _status = 'Checks complete');
  }

  void _addCheck(String msg) {
    setState(() => _checks.add(msg));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug Info')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_status, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _checks.length,
                itemBuilder: (ctx, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_checks[i], style: const TextStyle(fontFamily: 'monospace')),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _runChecks,
              child: const Text('Re-run Checks'),
            ),
          ],
        ),
      ),
    );
  }
}
