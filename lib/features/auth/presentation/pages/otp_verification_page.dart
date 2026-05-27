import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';

class OtpVerificationPage extends StatefulWidget {
  final String phoneNumber;

  const OtpVerificationPage({super.key, required this.phoneNumber});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  String _otp = '';
  String? _otpError;
  int _resendSeconds = AppConstants.otpTimeoutSeconds;
  Timer? _resendTimer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendSeconds = AppConstants.otpTimeoutSeconds;
    _canResend = false;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendSeconds > 0) {
          _resendSeconds--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  void _onNumpadTap(String digit) {
    if (_otp.length >= AppConstants.otpLength) return;
    setState(() {
      _otp += digit;
      if (_otpError != null) _otpError = null;
    });
    if (_otp.length == AppConstants.otpLength) {
      _verifyOtp();
    }
  }

  void _onBackspace() {
    if (_otp.isEmpty) return;
    setState(() {
      _otp = _otp.substring(0, _otp.length - 1);
      if (_otpError != null) _otpError = null;
    });
  }

  Future<void> _verifyOtp() async {
    final error = Validators.validateOtp(_otp);
    if (error != null) {
      setState(() => _otpError = error);
      return;
    }

    final auth = context.read<AuthProvider>();
    await auth.verifyOtp(_otp);

    if (!mounted) return;
    if (auth.status == AuthStatus.error) {
      setState(() {
        _otpError = auth.errorMessage ?? 'Verification failed';
        _otp = '';
      });
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;
    final auth = context.read<AuthProvider>();
    await auth.resendOtp(widget.phoneNumber);
    if (!mounted) return;
    if (auth.status == AuthStatus.otpSent) {
      _startResendTimer();
      setState(() => _otp = '');
    }
  }

  String get _maskedPhone {
    final phone = widget.phoneNumber;
    if (phone.length > 6) {
      return '${phone.substring(0, phone.length - 4)}XXXX';
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      context.read<AuthProvider>().resetToPhoneInput();
                      Navigator.of(context).pop();
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.arrow_back_rounded,
                          size: 18, color: cs.onSurface),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.help_outline_rounded,
                        size: 22, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // SMS icon
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.brandGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.sms_rounded,
                          color: AppColors.brandGreen, size: 26),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Enter the code',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Text(
                          'Sent to $_maskedPhone  ',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            context.read<AuthProvider>().resetToPhoneInput();
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            'Change',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Digit boxes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(AppConstants.otpLength, (i) {
                        final filled = i < _otp.length;
                        final isActive = i == _otp.length;
                        final hasError = _otpError != null;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 48,
                          height: 56,
                          decoration: BoxDecoration(
                            color: filled
                                ? cs.primary.withValues(alpha: 0.1)
                                : cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: hasError
                                  ? cs.error
                                  : isActive
                                      ? cs.primary
                                      : filled
                                          ? cs.primary.withValues(alpha: 0.5)
                                          : cs.outlineVariant,
                              width: isActive || hasError ? 2 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: filled
                              ? Text(
                                  _otp[i],
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                  ),
                                )
                              : isActive
                                  ? Container(
                                      width: 2,
                                      height: 24,
                                      color: cs.primary,
                                    )
                                  : null,
                        );
                      }),
                    ),

                    if (_otpError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _otpError!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.error),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Resend
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        return Row(
                          children: [
                            Icon(Icons.refresh_rounded,
                                size: 16,
                                color: _canResend
                                    ? cs.primary
                                    : cs.onSurfaceVariant),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: auth.isLoading ? null : _resendOtp,
                              child: Text(
                                _canResend
                                    ? 'Resend code'
                                    : 'Resend code in ${_resendSeconds}s',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _canResend
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                  fontWeight: _canResend
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    // Loading indicator
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        if (!auth.isLoading) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: LinearProgressIndicator(
                            color: cs.primary,
                            backgroundColor:
                                cs.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Custom numpad
            _Numpad(
              onDigit: _onNumpadTap,
              onBackspace: _onBackspace,
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Numpad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const _Numpad({required this.onDigit, required this.onBackspace});

  static const _labels = {
    '2': 'ABC',
    '3': 'DEF',
    '4': 'GHI',
    '5': 'JKL',
    '6': 'MNO',
    '7': 'PQRS',
    '8': 'TUV',
    '9': 'WXYZ',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: row.map((key) {
                    final sub = _labels[key];
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Material(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () => onDigit(key),
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              height: 60,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    key,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  if (sub != null)
                                    Text(
                                      sub,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        fontSize: 9,
                                        letterSpacing: 1.2,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              )),
          // Bottom row: blank, 0, backspace
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                // Left: blank placeholder
                const Expanded(child: SizedBox()),
                // 0
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Material(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => onDigit('0'),
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 60,
                          child: Center(
                            child: Text(
                              '0',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Backspace
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: InkWell(
                      onTap: onBackspace,
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 60,
                        child: Center(
                          child: Icon(Icons.backspace_outlined,
                              size: 22, color: cs.onSurface),
                        ),
                      ),
                    ),
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
