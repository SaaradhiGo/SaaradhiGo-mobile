import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../components/market_overlays.dart';

import '../../ui/appearance_settings.dart';
import '../../ui/sg_appearance.dart';
import '../../ui/sg_brand.dart';
import '../../ui/sg_text.dart';
import '../../ui/sg_tokens.dart';
import '../../ui/sg_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// Which credential the rider is using.
///
/// Mobile + OTP stays the default and the primary route: it is what the
/// pilot's riders have, it needs no password, and it is how an account is
/// created in the first place. Email + password is for someone who has set
/// one, and for QA accounts that must be reachable without waiting on SMS.
enum LoginMode { mobile, email }

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _mfaController = TextEditingController();

  LoginMode _mode = LoginMode.mobile;
  bool _showPassword = false;

  /// Only shown once the server has asked for it, which it does only for an
  /// operator account and only after the password was accepted.
  bool _needsMfa = false;

  Future<void> _safePushToOtp(String phone) async {
    // Avoid web focus traversal crash by releasing focus before route change.
    FocusManager.instance.primaryFocus?.unfocus();
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!mounted) return;
    context.push('/otp', extra: phone);
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter your email address')));
      return;
    }
    if (password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter your password')));
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final code = await auth.loginWithEmail(
      email: email,
      password: password,
      mfaCode: _needsMfa ? _mfaController.text.trim() : null,
    );

    if (!mounted) return;

    if (code == null) {
      // Straight to the app. No OTP screen: the password WAS the proof.
      context.go('/home');
      return;
    }

    if (code == 'AUTH_MFA_REQUIRED' || code == 'AUTH_MFA_INVALID') {
      setState(() => _needsMfa = true);
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(auth.error ?? 'Could not sign in')));
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your email address first, then tap again'),
        ),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.requestPasswordReset(email);
    if (!mounted) return;

    // The same message whatever the server found. It deliberately does not
    // confirm whether an account exists -- see the backend's
    // password_views.FORGOT_MESSAGE.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'If that address belongs to an account, we have sent a reset link.',
        ),
      ),
    );
  }

  Future<void> _requestOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // India still builds +91XXXXXXXXXX exactly as before; another market uses its own
    // dialling code from app-config.
    final formattedPhone =
        '${marketOf(context, listen: false).dialPrefix}$phone';
    final response = await authProvider.requestOtp(formattedPhone);

    if (!mounted) return;

    if (response != null && response['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent. Check your messages.')),
      );
      await _safePushToOtp(formattedPhone);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response?['message'] ?? 'Failed to request OTP. Please try again.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _mfaController.dispose();
    super.dispose();
  }

  /// Shown on a first launch only: no language saved on this device yet.
  late final bool _showLanguageTiles = !SgAppearance.instance.hasSavedLanguage;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final l = sgStrings(context);
    final mobile = _mode == LoginMode.mobile;

    return Scaffold(
      backgroundColor: SgColors.bg000,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  SgSpace.s5,
                  SgSpace.s4,
                  SgSpace.s5,
                  SgSpace.s4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: SgBrandLockup(badgeSize: 40),
                    ),
                    const SizedBox(height: SgSpace.s6),
                    if (_showLanguageTiles) ...[
                      Text(l.langChooseTitle, style: SgText.heading),
                      const SizedBox(height: SgSpace.s4),
                      for (final code in const ['te', 'hi', 'en'])
                        Padding(
                          padding: const EdgeInsets.only(bottom: SgSpace.s2),
                          child: LanguageTile(
                            key: Key('lang_tile_$code'),
                            label: languageLabel(l, code),
                            selected: SgAppearance.instance.language == code,
                            onTap: () =>
                                SgAppearance.instance.setLanguage(code),
                          ),
                        ),
                      const SizedBox(height: SgSpace.s5),
                    ],
                    Text(mobile ? l.phoneTitle : 'Email', style: SgText.title),
                    const SizedBox(height: SgSpace.s1),
                    Text(
                      mobile ? 'PHONE NUMBER' : 'EMAIL',
                      style: SgText.label,
                    ),
                    const SizedBox(height: SgSpace.s2),
                    if (!mobile) ...[
                      _EmailField(
                        key: const Key('login_email_field'),
                        controller: _emailController,
                      ),
                      const SizedBox(height: SgSpace.s3),
                      _PasswordField(
                        key: const Key('login_password_field'),
                        controller: _passwordController,
                        obscure: !_showPassword,
                        onToggle: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                      if (_needsMfa) ...[
                        const SizedBox(height: SgSpace.s3),
                        // Shown only for an operator account, and only
                        // after the password was already accepted.
                        _EmailField(
                          key: const Key('login_mfa_field'),
                          controller: _mfaController,
                          hint: '6-digit authenticator code',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const Key('login_forgot_password'),
                          onPressed: auth.isLoading ? null : _forgotPassword,
                          child: Text(
                            'Forgot password?',
                            style: SgText.body.copyWith(
                              color: SgColors.goldText,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (mobile)
                      _PhoneField(
                        controller: _phoneController,
                        dialPrefix: marketOf(context, listen: false).dialPrefix,
                        hint: l.phoneHint,
                      ),
                    const SizedBox(height: SgSpace.s2),
                    // Mobile is first and default: it is what a pilot rider
                    // has, it needs no password, and it is the only route
                    // that can CREATE an account. Email is for someone who
                    // has set a password, and for QA accounts that must be
                    // reachable without waiting on an SMS.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: Key(
                          mobile ? 'login_tab_email' : 'login_tab_mobile',
                        ),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, kSgTouch),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () => setState(() {
                          _mode = mobile ? LoginMode.email : LoginMode.mobile;
                          _needsMfa = false;
                        }),
                        child: Text(
                          mobile ? l.useEmail : l.useMobile,
                          style: SgText.body.copyWith(
                            color: SgColors.goldText,
                            fontWeight: FontWeight.w700,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (auth.isLoading)
                    const SizedBox(
                      height: 56,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: SgColors.gold500,
                        ),
                      ),
                    )
                  else
                    SgPrimaryButton(
                      key: const Key('login_submit'),
                      label: mobile ? l.sendCode : 'Sign in',
                      onPressed: mobile ? _requestOtp : _signInWithEmail,
                    ),
                  const SizedBox(height: SgSpace.s3),
                  Text(
                    l.termsLine,
                    textAlign: TextAlign.center,
                    style: SgText.caption.copyWith(fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the three first-launch language tiles: 68px, its name in its own
/// script, a radio on the right.
class LanguageTile extends StatelessWidget {
  const LanguageTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: selected ? SgColors.goldSoft : SgColors.bg200,
      borderRadius: BorderRadius.circular(SgRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SgRadius.md),
        child: AnimatedContainer(
          duration: SgMotion.press,
          curve: SgMotion.curve,
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: SgSpace.s4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SgRadius.md),
            border: Border.all(
              color: selected ? SgColors.gold500 : SgColors.line,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: SgText.title.copyWith(fontSize: 20, height: 26 / 20),
                ),
              ),
              SgRadio(selected: selected),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The phone field: dialling code from the market config, then the number.
class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.dialPrefix,
    required this.hint,
  });

  final TextEditingController controller;
  final String dialPrefix;
  final String hint;

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    decoration: BoxDecoration(
      color: SgColors.bg200,
      border: Border.all(color: SgColors.lineStrong),
      borderRadius: BorderRadius.circular(SgRadius.md),
    ),
    child: Row(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SgSpace.s4),
          child: Text(
            dialPrefix,
            style: SgText.title.copyWith(fontSize: 20, height: 26 / 20),
          ),
        ),
        Container(width: 1, height: 32, color: SgColors.line),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            style: SgText.title.copyWith(
              fontSize: 20,
              height: 26 / 20,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: SgText.body.copyWith(color: SgColors.inkSubtle),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: SgSpace.s3,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// A dark text field matching the phone input's styling.
class _EmailField extends StatelessWidget {
  const _EmailField({
    super.key,
    required this.controller,
    this.hint = 'you@example.com',
    this.keyboardType = TextInputType.emailAddress,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: SgColors.bg200,
        border: Border.all(color: SgColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        // An email field must not be "helped": autocorrect turns an address
        // into a word, and suggestions offer the last person's address on a
        // shared phone.
        autocorrect: false,
        enableSuggestions: false,
        style: TextStyle(color: SgColors.ink, fontSize: 17),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(color: SgColors.inkSubtle, fontSize: 16),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    super.key,
    required this.controller,
    required this.obscure,
    required this.onToggle,
  });

  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: SgColors.bg200,
        border: Border.all(color: SgColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.only(left: 16, right: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              autocorrect: false,
              enableSuggestions: false,
              style: TextStyle(color: SgColors.ink, fontSize: 17),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Password',
                hintStyle: TextStyle(color: SgColors.inkSubtle, fontSize: 16),
              ),
            ),
          ),
          IconButton(
            key: const Key('login_password_visibility'),
            onPressed: onToggle,
            icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: SgColors.inkMuted,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
