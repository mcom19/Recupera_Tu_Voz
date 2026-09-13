import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'voz_menu_card.dart';

// ── Animated waveform bar ─────────────────────────────────────────
class WaveBar extends StatefulWidget {
  final bool animated;
  final Color color;
  final int barCount;
  final double height;

  const WaveBar({
    super.key,
    this.animated = false,
    this.color = AppColors.accent,
    this.barCount = 28,
    this.height = 40,
  });

  @override
  State<WaveBar> createState() => _WaveBarState();
}

class _WaveBarState extends State<WaveBar> with SingleTickerProviderStateMixin {
  AdaptiveColors get c => AdaptiveColors.of(context);

  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.animated) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(WaveBar old) {
    super.didUpdateWidget(old);
    if (widget.animated && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.animated && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static const _baseHeights = [
    5, 9, 16, 26, 20, 13, 7, 19, 28, 22, 15, 9, 21, 30, 24, 17, 11, 23, 32,
    26, 19, 13, 21, 15, 9, 17, 24, 18, 13, 7
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.barCount, (i) {
              final base =
              _baseHeights[i % _baseHeights.length].toDouble();
              final factor =
              widget.animated ? (0.6 + 0.4 * _ctrl.value) : 1.0;
              final h = (base * factor).clamp(4.0, widget.height - 4);
              return Container(
                width: 4,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// ── Speak button ──────────────────────────────────────────────────
class SpeakButton extends StatelessWidget {
  final bool isSpeaking;
  final bool isLoading;
  final VoidCallback onTap;

  const SpeakButton({
    super.key,
    required this.isSpeaking,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 200,
        height: 76,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSpeaking ? c.accent : c.border,
            width: 1.8,
          ),
          gradient: isSpeaking
              ? LinearGradient(
            colors: [
              c.accent.withValues(alpha: 0.22),
              c.teal.withValues(alpha: 0.12),
            ],
          )
              : null,
          color: isSpeaking ? null : c.surface,
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: c.accent,
            ),
          )
              : isSpeaking
              ? Icon(Icons.stop_rounded,
              color: c.accent, size: 38)
              : _WaveButtonIcon(),
        ),
      ),
    );
  }
}

class _WaveButtonIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    const heights = [
      7.0, 14.0, 26.0, 34.0, 26.0, 18.0, 34.0, 26.0, 18.0, 26.0, 14.0, 7.0
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(12, (i) {
        return Container(
          width: 5,
          height: heights[i],
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [c.teal, c.accent],
            ),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────
class SectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsets? padding;

  const SectionLabel(this.text, {super.key, this.padding});

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: c.textDim,
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Accent text field ─────────────────────────────────────────────
class AccentTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int? maxLines;
  final bool expands;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;

  const AccentTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.expands = false,
    this.obscureText = false,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    return Container(
      decoration: vozCardDecoration(radius: 10),
      child: TextField(
        controller: controller,
        maxLines: expands ? null : maxLines,
        expands: expands,
        obscureText: obscureText,
        textAlignVertical: expands ? TextAlignVertical.top : null,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted != null ? (_) => onSubmitted!() : null,
        style: TextStyle(color: c.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
          hintText: hint,
          hintStyle: TextStyle(color: c.textDim, fontSize: 15),
        ),
      ),
    );
  }
}

// ── Chip selector row ─────────────────────────────────────────────
class ChipRow extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;
  final Color Function(String)? colorOf;

  const ChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.colorOf,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((opt) {
          final sel = opt == selected;
          final color = colorOf?.call(opt) ?? c.accent;
          return GestureDetector(
            onTap: () => onSelect(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? color.withValues(alpha: 0.15) : Colors.transparent,
                border: Border.all(
                  color: sel ? color : c.border,
                  width: sel ? 1.4 : 1,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                opt,
                style: TextStyle(
                  color: sel ? color : c.textDim,
                  fontSize: 13,
                  fontWeight:
                  sel ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Teal primary button ───────────────────────────────────────────
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    final clr = color ?? c.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: clr,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: c.bg,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Auth widgets (usados en login/register) ───────────────────────
class AuthField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final bool obscure;
  final TextInputType? type;
  final VoidCallback? onSubmit;

  const AuthField({super.key,
    required this.ctrl,
    required this.label,
    required this.hint,
    this.obscure = false,
    this.type,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(label,
              style: TextStyle(
                  color: c.textMid,
                  fontSize: 12,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600)),
        ),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.border),
          ),
          child: TextField(
            controller: ctrl,
            obscureText: obscure,
            keyboardType: type,
            onSubmitted: onSubmit != null ? (_) => onSubmit!() : null,
            style: TextStyle(color: c.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
              hintText: hint,
              hintStyle:
              TextStyle(color: c.textDim, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}

class AuthButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const AuthButton(
      {super.key, required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AdaptiveColors.of(context);
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: loading
              ? const SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}