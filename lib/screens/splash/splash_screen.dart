import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import '../../ui/sg_brand.dart';
import '../../ui/sg_text.dart';
import '../../ui/sg_tokens.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  /// The badge while the permissions are asked, then sign-in. The stock-photo onboarding slides
  /// ("Our Inspiration", "Better Together") are gone (product standard, 17 Nov 2026): the app
  /// opens on what it is for, like the other ride apps.
  Future<void> _start() async {
    await _requestPermissions();
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) _completeFirstLaunch(context);
  }

  Future<void> _requestPermissions() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      debugPrint('Initial Permissions - Notification requested, Location: $permission');
    } catch (e) {
      debugPrint('Error requesting initial permissions: $e');
    }
  }

  void _completeFirstLaunch(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);
    if (context.mounted) {
      context.go('/login');
    }
  }

  /// The badge, "Saaradhi Go" and a plain spinner. No progress figure: the app
  /// does not know how far along it is, so it does not pretend to.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SgColors.bg000,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SgBrandBadge(size: 120),
            const SizedBox(height: SgSpace.s4),
            Text('Saaradhi Go', style: SgText.brandLockup(32)),
            const SizedBox(height: SgSpace.s6),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                key: const Key('splash_spinner'),
                strokeWidth: 2.5,
                color: SgColors.gold500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
