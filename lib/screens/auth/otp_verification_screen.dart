import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/push_notification_service.dart';
import '../../providers/auth_provider.dart';

import 'package:flutter/services.dart';
import '../../ui/appearance_settings.dart';
import '../../ui/sg_text.dart';
import '../../ui/sg_tokens.dart';
import '../../ui/sg_widgets.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  // One field behind the six boxes, so an SMS code the keyboard offers
  // (AutofillHints.oneTimeCode) or a pasted code fills all six at once.
  final TextEditingController _code = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  int _resendTimeout = 59;
  Timer? _timer;
  bool _canResend = false;

  Future<void> _safePushToProfile() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!mounted) return;
    context.push('/profile-setup');
  }

  Future<void> _safePop() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!mounted) return;
    context.pop();
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() {
      _resendTimeout = 59;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimeout > 0) {
        setState(() {
          _resendTimeout--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  void _resendOtp() async {
    if (!_canResend) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final response = await authProvider.requestOtp(widget.phoneNumber);

    if (response != null && response['status'] == 'success') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'New OTP sent. Check your messages.',
              style: TextStyle(color: SgColors.onDanger),
            ),
            backgroundColor: SgColors.success,
          ),
        );
      }
      _startTimer();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authProvider.error ?? 'Failed to resend OTP',
            style: TextStyle(color: SgColors.onDanger),
          ),
          backgroundColor: SgColors.danger,
        ),
      );
    }
  }

  void _verifyOtp() async {
    final otp = _code.text;
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter the complete 6-digit OTP',
            style: TextStyle(color: SgColors.ink),
          ),
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Null, not a placeholder. This defaulted to the literal 'dummy_token'
    // whenever FCM was unavailable -- no Play Services, permission declined,
    // no network at launch -- and the backend stored it. The row then held a
    // token that could never receive anything, while dispatch's filter
    // counted this rider as push-capable. An absent key leaves a previously
    // good token alone, which is what the login view is written to do.
    String? deviceToken;
    try {
      deviceToken = await PushNotificationService.getToken();
    } catch (e) {
      debugPrint('Error handling FCM token: $e');
    }

    final success = await authProvider.verifyOtp(
      widget.phoneNumber,
      otp,
      deviceToken,
    );

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'OTP verified successfully',
              style: TextStyle(color: SgColors.onDanger),
            ),
            backgroundColor: SgColors.success,
          ),
        );
        if (authProvider.isUpdated) {
          await SchedulerBinding.instance.endOfFrame;
          if (mounted) context.go('/home');
        } else {
          await _safePushToProfile();
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              authProvider.error ?? 'Verification failed',
              style: TextStyle(color: SgColors.onDanger),
            ),
            backgroundColor: SgColors.danger,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = sgStrings(context);
    final timer = '0:${_resendTimeout.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: SgColors.bg000,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SgSpace.s2,
                SgSpace.s2,
                SgSpace.s4,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Back',
                  constraints: const BoxConstraints(
                    minWidth: kSgTouch,
                    minHeight: kSgTouch,
                  ),
                  onPressed: _safePop,
                  icon: SgIcon(SgIcons.back, size: 24, color: SgColors.ink),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  SgSpace.s5,
                  SgSpace.s3,
                  SgSpace.s5,
                  SgSpace.s4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l.verifyTitle, style: SgText.display),
                    const SizedBox(height: SgSpace.s2),
                    // The number the code went to; never a sample number.
                    if (widget.phoneNumber.isNotEmpty)
                      Text(
                        l.verifySentTo(widget.phoneNumber),
                        style: SgText.body.copyWith(color: SgColors.inkMuted),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: const Key('otp_change_number'),
                        onPressed: _safePop,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, kSgTouch),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          l.changeNumber,
                          style: SgText.body.copyWith(
                            color: SgColors.goldText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: SgSpace.s4),
                    OtpBoxes(
                      controller: _code,
                      focusNode: _codeFocus,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: SgSpace.s5),
                    Center(
                      child: _canResend
                          ? TextButton(
                              key: const Key('otp_resend'),
                              onPressed: _resendOtp,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, kSgTouch),
                              ),
                              child: Text(
                                l.verifyResend,
                                style: SgText.body.copyWith(
                                  color: SgColors.goldText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: SgSpace.s3,
                              ),
                              child: Text(
                                l.verifyResendIn(timer),
                                style: SgText.caption.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SgSpace.s5,
                SgSpace.s2,
                SgSpace.s5,
                SgSpace.s4,
              ),
              child: Consumer<AuthProvider>(
                builder: (context, auth, child) => auth.isLoading
                    ? SizedBox(
                        height: 56,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: SgColors.gold500,
                          ),
                        ),
                      )
                    : SgPrimaryButton(
                        key: const Key('otp_verify'),
                        label: l.verifyButton,
                        onPressed: _verifyOtp,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Six boxes over one hidden field. Typing, pasting or an SMS code offered by
/// the keyboard all land in the one field; the boxes only draw it.
class OtpBoxes extends StatelessWidget {
  const OtpBoxes({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String>? onChanged;

  static const length = 6;

  @override
  Widget build(BuildContext context) {
    final code = controller.text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: focusNode.requestFocus,
      child: Stack(
        children: [
          // Kept in the tree and focusable, but drawn invisibly.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                key: const Key('otp_field'),
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: length,
                showCursor: false,
                enableInteractiveSelection: false,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(counterText: ''),
                onChanged: onChanged,
              ),
            ),
          ),
          ListenableBuilder(
            listenable: focusNode,
            builder: (context, _) => Row(
              children: [
                for (var i = 0; i < length; i++) ...[
                  if (i > 0) const SizedBox(width: SgSpace.s2),
                  Expanded(
                    child: Container(
                      key: Key('otp_box_$i'),
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: SgColors.bg200,
                        borderRadius: BorderRadius.circular(SgRadius.md),
                        border: Border.all(
                          color:
                              focusNode.hasFocus &&
                                  i == code.length.clamp(0, length - 1)
                              ? SgColors.gold500
                              : SgColors.lineStrong,
                          width:
                              focusNode.hasFocus &&
                                  i == code.length.clamp(0, length - 1)
                              ? 2.5
                              : 1,
                        ),
                      ),
                      child: Text(
                        i < code.length ? code[i] : '',
                        style: SgText.fare.copyWith(
                          fontSize: SgText.sizeHeading,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
