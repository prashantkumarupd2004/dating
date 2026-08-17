import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_scaffold.dart';

class ListenerVoiceVerificationScreen extends StatefulWidget {
  const ListenerVoiceVerificationScreen({super.key});
  @override
  State<ListenerVoiceVerificationScreen> createState() => _ListenerVoiceVerificationScreenState();
}

class _ListenerVoiceVerificationScreenState extends State<ListenerVoiceVerificationScreen> {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _recorded = false;
  String? _audioPath;
  int _seconds = 0;
  static const _minSeconds = 10;
  static const _maxSeconds = 30;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission required'), backgroundColor: AppColors.error),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_sample_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100), path: path);
    setState(() { _isRecording = true; _seconds = 0; _audioPath = path; });
    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_isRecording) return;
      setState(() => _seconds++);
      if (_seconds < _maxSeconds) _tick();
      else _stopRecording();
    });
  }

  Future<void> _stopRecording() async {
    if (_seconds < _minSeconds) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please record at least 10 seconds'), backgroundColor: AppColors.error),
      );
      return;
    }
    await _recorder.stop();
    setState(() { _isRecording = false; _recorded = true; });
  }

  void _retake() {
    if (_audioPath != null) {
      try { File(_audioPath!).deleteSync(); } catch (_) {}
    }
    setState(() { _recorded = false; _audioPath = null; _seconds = 0; });
  }

  void _proceed() => context.go('/listener/register-full', extra: _audioPath);

  String get _timerLabel {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color get _timerColor {
    if (_seconds < _minSeconds) return AppColors.error;
    if (_seconds < 20) return AppColors.success;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(title: const Text('Voice Verification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Sample script card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.accentStart.withValues(alpha: 0.1), AppColors.accentEnd.withValues(alpha: 0.06)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accentStart.withValues(alpha: 0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  ShaderMask(
                    shaderCallback: (b) => AppColors.accentGradient.createShader(b),
                    child: const Icon(Icons.record_voice_over_rounded, size: 24, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Text('Say this out loud:', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '"Hello! My name is [your name], I am [age] years old. I am from [your city]. My hobbies are [your hobbies]. I love talking about [topics you enjoy]. I am excited to connect with people on Milan!"',
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textPrimary, height: 1.6, fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 10),
                Text('Minimum 10 seconds • Speak clearly in your natural voice', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textHint)),
              ]),
            ),

            const SizedBox(height: 36),

            // Recording button
            if (!_recorded) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _isRecording ? 110 : 90,
                height: _isRecording ? 110 : 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _isRecording
                      ? const LinearGradient(colors: [Color(0xFFFF2D2D), Color(0xFFFF2D9B)])
                      : AppColors.accentGradient,
                  boxShadow: [BoxShadow(
                    color: (_isRecording ? const Color(0xFFFF2D2D) : AppColors.accentStart).withValues(alpha: 0.4),
                    blurRadius: _isRecording ? 30 : 16,
                    spreadRadius: _isRecording ? 4 : 0,
                  )],
                ),
                child: GestureDetector(
                  onTap: _isRecording ? _stopRecording : _startRecording,
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_isRecording) ...[
                Text(_timerLabel, style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w800, color: _timerColor)),
                const SizedBox(height: 4),
                Text(
                  _seconds < _minSeconds
                      ? 'Keep recording... (${_minSeconds - _seconds}s more needed)'
                      : 'Tap stop when done',
                  style: GoogleFonts.poppins(fontSize: 12, color: _timerColor),
                ),
              ] else ...[
                Text('Tap to start recording', style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary)),
              ],
            ] else ...[
              // Recorded state
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withValues(alpha: 0.12),
                  border: Border.all(color: AppColors.success, width: 2),
                ),
                child: const Icon(Icons.check_rounded, color: AppColors.success, size: 48),
              ),
              const SizedBox(height: 14),
              Text('Voice recorded! ($_timerLabel)', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.success)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _retake,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Re-record'),
              ),
            ],

            const SizedBox(height: 32),
            Text(
              'Your voice sample will be reviewed by our team. Make sure you speak clearly.',
              style: const TextStyle(color: AppColors.textHint, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _recorded ? _proceed : null,
                child: const Text('Continue to Registration'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
