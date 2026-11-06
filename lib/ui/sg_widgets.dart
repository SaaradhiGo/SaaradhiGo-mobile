/// Small design-system pieces shared by the home and booking screens.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'sg_text.dart';
import 'sg_tokens.dart';

/// 24px line icons, 1.75 stroke, round caps (design-system Iconography).
class SgIcons {
  SgIcons._();
  static const menu = '<path d="M4 7h16M4 12h16M4 17h10"/>';
  static const user =
      '<circle cx="12" cy="8" r="4"/><path d="M4 21c1-4 4-6 8-6s7 2 8 6"/>';
  static const home = '<path d="M4 11l8-7 8 7v9h-5v-6H9v6H4z"/>';
  static const work =
      '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M9 7V5h6v2M3 13h18"/>';
  static const clock = '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>';
  static const pin =
      '<path d="M12 21s-7-6-7-11a7 7 0 0114 0c0 5-7 11-7 11z"/><circle cx="12" cy="10" r="2.5"/>';
  static const close = '<path d="M6 6l12 12M18 6L6 18"/>';
  static const back = '<path d="M15 5l-7 7 7 7"/>';
  static const cash =
      '<rect x="3" y="6" width="18" height="12" rx="2"/><circle cx="12" cy="12" r="2.5"/>';
  static const bell =
      '<path d="M6 17V11a6 6 0 0112 0v6l2 2H4z"/><path d="M10 21h4"/>';
  static const history =
      '<path d="M3 12a9 9 0 109-9 9 9 0 00-6.4 2.6L3 8"/><path d="M3 3v5h5M12 7v5l3 2"/>';
  static const wallet =
      '<path d="M3 7a2 2 0 012-2h13v4"/><rect x="3" y="7" width="18" height="13" rx="2"/><path d="M16 13.5h2"/>';
  static const call =
      '<path d="M5 4h4l2 5-2.5 1.5a11 11 0 005 5L15 13l5 2v4a2 2 0 01-2 2A16 16 0 013 6a2 2 0 012-2"/>';
  static const message = '<path d="M4 5h16v11H9l-5 4z"/>';
  static const share = '<path d="M12 3v12M7 8l5-5 5 5M5 14v6h14v-6"/>';
  static const shield =
      '<path d="M12 3l8 3v6c0 5-4 8-8 9-4-1-8-4-8-9V6z"/><path d="M12 8v5M12 16v.5"/>';
  static const check = '<path d="M5 12l5 5 9-10"/>';
  static const lock =
      '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 018 0v3"/>';
  static const theme =
      '<circle cx="12" cy="12" r="4"/><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6l1.4 1.4M17 17l1.4 1.4M5.6 18.4L7 17M17 7l1.4-1.4"/>';
  static const language =
      '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18"/>';
  static const help =
      '<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 115 0c0 1.5-2.5 2-2.5 3.5M12 17h.01"/>';
}

class SgIcon extends StatelessWidget {
  const SgIcon(this.body, {super.key, this.size = 20, Color? color})
    : _color = color;
  final String body;
  final double size;
  final Color? _color;
  Color get color => _color ?? SgColors.inkMuted;

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
    'stroke="currentColor" stroke-width="1.75" stroke-linecap="round" '
    'stroke-linejoin="round">$body</svg>',
    width: size,
    height: size,
    theme: SvgTheme(currentColor: color),
  );
}

/// Round 48px button floating over the map.
class SgMapButton extends StatelessWidget {
  const SgMapButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: kSgTouch,
        height: kSgTouch,
        decoration: BoxDecoration(
          color: SgColors.bg100,
          shape: BoxShape.circle,
          border: Border.all(color: SgColors.goldLine),
          boxShadow: [
            BoxShadow(
              color: SgColors.shadow,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Center(child: SgIcon(icon, size: 20, color: SgColors.ink)),
      ),
    ),
  );
}

/// The one gold button on a screen.
class SgPrimaryButton extends StatelessWidget {
  const SgPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final on = onPressed != null;
    return Material(
      color: on ? SgColors.gold500 : SgColors.bg300,
      borderRadius: BorderRadius.circular(SgRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(SgRadius.md),
        onTap: onPressed,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: SgSpace.s5),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SgText.button.copyWith(
              color: on ? SgColors.onGold : SgColors.inkSubtle,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet surface: bg-100, gold hairline edge, grab handle.
class SgSheetSurface extends StatelessWidget {
  const SgSheetSurface({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: SgColors.bg100,
      borderRadius: BorderRadius.vertical(top: Radius.circular(SgRadius.lg)),
      border: Border(top: BorderSide(color: SgColors.goldLine)),
      boxShadow: [
        BoxShadow(
          color: SgColors.shadow,
          blurRadius: 40,
          offset: Offset(0, -12),
        ),
      ],
    ),
    padding:
        padding ??
        const EdgeInsets.fromLTRB(
          SgSpace.s4,
          SgSpace.s3,
          SgSpace.s4,
          SgSpace.s4,
        ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: SgSpace.s4),
            decoration: BoxDecoration(
              color: SgColors.lineStrong,
              borderRadius: BorderRadius.circular(SgRadius.pill),
            ),
          ),
        ),
        Flexible(child: child),
      ],
    ),
  );
}
