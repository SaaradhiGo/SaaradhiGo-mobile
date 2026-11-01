import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email address')),
      );
      return;
    }
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your password')),
      );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(auth.error ?? 'Could not sign in')),
    );
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
    final formattedPhone = '+91$phone';
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF12110D),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Container(color: const Color(0xFF12110D)),
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: CustomPaint(painter: _MapGridPainter()),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x1A000000), Color(0xAA000000)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(
                    children: [
                      _CircleIconButton(icon: Icons.close, onTap: () {}),
                      const Spacer(),
                      const Text(
                        'SAARADHIGO',
                        style: TextStyle(
                          letterSpacing: 2,
                          color: Color(0xFFEEBD2B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(
                        width: 40,
                        child: Text(
                          'Help',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Color(0xCCEEBD2B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome to SaaradhiGo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            height: 1.05,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Enter your mobile number to start your premium journey.',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 42),

                        // Mobile | Email.
                        //
                        // Mobile is first and default: it is what a pilot
                        // rider has, it needs no password, and it is the only
                        // route that can CREATE an account. Email is for
                        // someone who has set a password, and for QA accounts
                        // that must be reachable without waiting on an SMS.
                        Row(
                          children: [
                            _ModeTab(
                              key: const Key('login_tab_mobile'),
                              label: 'Mobile',
                              selected: _mode == LoginMode.mobile,
                              onTap: () => setState(() {
                                _mode = LoginMode.mobile;
                                _needsMfa = false;
                              }),
                            ),
                            const SizedBox(width: 8),
                            _ModeTab(
                              key: const Key('login_tab_email'),
                              label: 'Email',
                              selected: _mode == LoginMode.email,
                              onTap: () =>
                                  setState(() => _mode = LoginMode.email),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        Text(
                          _mode == LoginMode.mobile ? 'PHONE NUMBER' : 'EMAIL',
                          style: const TextStyle(
                            color: Color(0xFFEEBD2B),
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (_mode == LoginMode.email) ...[
                          _EmailField(
                            key: const Key('login_email_field'),
                            controller: _emailController,
                          ),
                          const SizedBox(height: 12),
                          _PasswordField(
                            key: const Key('login_password_field'),
                            controller: _passwordController,
                            obscure: !_showPassword,
                            onToggle: () => setState(
                                () => _showPassword = !_showPassword),
                          ),
                          if (_needsMfa) ...[
                            const SizedBox(height: 12),
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
                              onPressed:
                                  auth.isLoading ? null : _forgotPassword,
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(color: Color(0xFFEEBD2B)),
                              ),
                            ),
                          ),
                        ],

                        if (_mode == LoginMode.mobile)
                        Container(
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            border: Border.all(color: Colors.white10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Row(
                                  children: const [
                                    Text(
                                      '+91',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: Colors.white10,
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: '555 000-0000',
                                    hintStyle: TextStyle(
                                      color: Color(0xFF475569),
                                      fontSize: 30,
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 64,
                          child: ElevatedButton(
                            key: const Key('login_submit'),
                            onPressed: auth.isLoading
                                ? null
                                : (_mode == LoginMode.mobile
                                    ? _requestOtp
                                    : _signInWithEmail),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEEBD2B),
                              foregroundColor: const Color(0xFF12110D),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: auth.isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    _mode == LoginMode.mobile
                                        ? 'Continue'
                                        : 'Sign in',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        Row(
                          children: const [
                            Expanded(child: Divider(color: Colors.white10)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'OR CONTINUE WITH',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.white10)),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: const [
                            Expanded(
                              child: _SocialChip(
                                icon: Icons.g_mobiledata,
                                label: 'Google',
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: _SocialChip(
                                icon: Icons.apple,
                                label: 'Apple',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                  child: Column(
                    children: [
                      Text.rich(
                        TextSpan(
                          text: 'By continuing, you agree to SaaradhiGo\'s ',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                color: Color(0xCCEEBD2B),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: Color(0xCCEEBD2B),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 36,
        width: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _SocialChip extends StatelessWidget {
  const _SocialChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
        color: Colors.white.withValues(alpha: 0.06),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;
    const gap = 36.0;

    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// One of the two credential tabs.
class _ModeTab extends StatelessWidget {
  const _ModeTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFEEBD2B)
                : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: selected ? const Color(0xFFEEBD2B) : Colors.white10,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF12110D) : Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
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
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white10),
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
        style: const TextStyle(color: Colors.white, fontSize: 17),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 16),
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
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white10),
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
              style: const TextStyle(color: Colors.white, fontSize: 17),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Password',
                hintStyle: TextStyle(color: Color(0xFF475569), fontSize: 16),
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
              color: const Color(0xFF94A3B8),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
