import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_config.dart';
import '../../core/data/auth_repository.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import 'auth_provider.dart';

/// Turkmen mobile numbers are 8 digits after the +993 country code, e.g.
/// 62 99 03 44.
const int _phoneDigits = 8;

/// Phone + SMS code. No passwords — couriers change phones, not credentials.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Holds only the local number — the +993 prefix is a fixed decoration, not
  /// editable text, so it can never be typed over or float as a label.
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The "Получить код" / "Войти" buttons live in this state's build, but the
    // fields are separate widgets below — only a listener here, not a rebuild
    // triggered from inside the field itself, reaches the button's enabled
    // check on every keystroke.
    _phone.addListener(_onFieldChanged);
    _code.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _onFieldChanged() => setState(() {});

  bool get _phoneValid => _phone.text.length == _phoneDigits;
  bool get _isValidOtpLength =>
      _code.text.length == 4 || _code.text.length == 6;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final locale = context.watch<LocaleProvider>();
    final s = locale.strings;
    final onCodeStage = auth.stage == AuthStage.code;

    return Scaffold(
      backgroundColor: AppColors.green,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  if (onCodeStage)
                    IconButton(
                      onPressed: () =>
                          context.read<AuthProvider>().backToPhone(),
                      icon: const HugeIcon(
                        icon: AppIcons.back,
                        color: AppColors.white,
                        size: 24,
                      ),
                    ),
                  const Spacer(),
                  // Language before sign-in: a Turkmen-only speaker must be
                  // able to read the very first screen.
                  _LanguageSwitch(
                    current: s.languageCode,
                    onSelect: (strings) => locale.select(strings),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HugeIcon(
                    icon: AppIcons.courier,
                    color: AppColors.orange,
                    size: 54,
                  ),
                  const SizedBox(height: 20),
                  Text(s.loginTitle, style: AppText.h1.copyWith(fontSize: 30)),
                  const SizedBox(height: 8),
                  Text(
                    onCodeStage ? s.smsCodeHint : s.loginSubtitle,
                    style: AppText.body.copyWith(color: AppColors.greenMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: onCodeStage
                  ? _CodeField(
                      controller: _code,
                      label: s.smsCode,
                      errorMessage: auth.codeRejected ? s.codeInvalid : null,
                    )
                  : _PhoneField(controller: _phone, label: s.phoneNumber),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AppButton(
                label: onCodeStage ? s.verify : s.requestCode,
                busy: auth.busy,
                onPressed: onCodeStage
                    ? (_isValidOtpLength ? () => _verify(auth) : null)
                    : (_phoneValid ? () => _requestCode(auth, s) : null),
              ),
            ),
            if (AppConfig.useMockData) ...[
              const SizedBox(height: 14),
              Center(
                child: Text(
                  s.demoHint,
                  style: AppText.bodyMuted.copyWith(
                    color: AppColors.greenMuted,
                  ),
                ),
              ),
            ],
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Future<void> _requestCode(AuthProvider auth, AppStrings s) async {
    try {
      await auth.requestCode('+993${_phone.text}');
    } on OtpRequestException catch (e) {
      if (!mounted) return;
      final message = e.isRateLimited ? s.otpTooManyRequests : s.otpRequestFailed;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _verify(AuthProvider auth) async {
    final ok = await auth.verify(_code.text.trim());
    if (!ok && mounted) {
      // Wrong code — clear the field so the courier can just retype. clear()
      // notifies the listener registered in initState, which rebuilds this
      // screen on its own.
      _code.clear();
    }
  }
}

/// Caption sitting above a field instead of a Material floating label.
///
/// A floating label that snaps to its raised position immediately (which
/// happens here: both fields autofocus, and the phone field always has a
/// fixed prefix) ends up drawn straddling the border line — half over the
/// dark scaffold, half over the white fill — and reads as ghosted. A plain
/// caption above the box never has that problem.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: AppText.label.copyWith(color: AppColors.greenMuted),
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          autofocus: true,
          style: AppText.h2.copyWith(
            color: AppColors.textPrimary,
            fontSize: 20,
          ),
          decoration: InputDecoration(
            // Fixed prefix — never editable, so it can't be deleted or
            // mistaken for placeholder text.
            prefixText: '+993 ',
            hintText: '62 99 03 44',
            // Without an explicit style the hint inherits the same dark input
            // colour and reads as if a number were already typed.
            hintStyle: AppText.h2.copyWith(
              color: AppColors.textMuted,
              fontSize: 20,
            ),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(_phoneDigits),
          ],
        ),
      ],
    );
  }
}

class _CodeField extends StatelessWidget {
  const _CodeField({
    required this.controller,
    required this.label,
    required this.errorMessage,
  });

  final TextEditingController controller;
  final String label;

  /// `null` when the last attempt hasn't failed. Shown as real error text, not
  /// just a border colour — the field is still focused (keyboard still up)
  /// right after the courier taps "Войти", and a focused field ignores
  /// `enabledBorder`, so a border-only signal would go unseen.
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          textAlign: TextAlign.center,
          style: AppText.h1.copyWith(
            color: AppColors.textPrimary,
            fontSize: 30,
            letterSpacing: 14,
          ),
          decoration: InputDecoration(
            errorText: errorMessage,
            errorMaxLines: 2,
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.red, width: 1.6),
            ),
            // Applies even while the field still has focus, unlike
            // enabledBorder — that's the part the old version missed.
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.red, width: 1.6),
            ),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
        ),
      ],
    );
  }
}

class _LanguageSwitch extends StatelessWidget {
  const _LanguageSwitch({required this.current, required this.onSelect});

  final String current;
  final void Function(dynamic strings) onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final strings in LocaleProvider.supported)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: GestureDetector(
              onTap: () => onSelect(strings),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: strings.languageCode == current
                      ? AppColors.orange
                      : AppColors.greenSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  strings.languageCode.toUpperCase(),
                  style: AppText.chip.copyWith(color: AppColors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
