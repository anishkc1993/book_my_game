import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';

class PhoneInputPage extends StatefulWidget {
  const PhoneInputPage({super.key});

  @override
  State<PhoneInputPage> createState() => _PhoneInputPageState();
}

class _PhoneInputPageState extends State<PhoneInputPage> {
  final _phoneController = TextEditingController();
  final _focusNode = FocusNode();
  String? _phoneError;
  String? _pendingPhoneNumber;

  @override
  void initState() {
    super.initState();
    // Listen to auth status changes for async callbacks (important for Android)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().addListener(_onAuthStatusChanged);
    });
  }

  @override
  void dispose() {
    // Remove listener to avoid memory leaks
    try {
      context.read<AuthProvider>().removeListener(_onAuthStatusChanged);
    } catch (_) {
      // Context might not be available during dispose
    }
    _phoneController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onAuthStatusChanged() {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();

    if (authProvider.status == AuthStatus.otpSent && _pendingPhoneNumber != null) {
      final phone = _pendingPhoneNumber!;
      _pendingPhoneNumber = null;
      context.push(RoutePaths.otpVerification, extra: phone);
    } else if (authProvider.status == AuthStatus.authenticated) {
      // Auto-verified on Android
      _pendingPhoneNumber = null;
      context.go(RoutePaths.home);
    } else if (authProvider.status == AuthStatus.error && _pendingPhoneNumber != null) {
      _pendingPhoneNumber = null;
      _showError(authProvider.errorMessage ?? 'Failed to send OTP');
    }
  }

  void _validateAndSubmit() {
    final error = Validators.validatePhoneNumber(_phoneController.text);
    setState(() {
      _phoneError = error;
    });

    if (error == null) {
      _sendOtp();
    }
  }

  Future<void> _sendOtp() async {
    final authProvider = context.read<AuthProvider>();
    final phoneNumber = Validators.formatPhoneNumber(
      _phoneController.text,
      countryCode: AppConstants.defaultCountryCode,
    );

    _pendingPhoneNumber = phoneNumber;
    await authProvider.sendOtp(phoneNumber);

    // Note: Navigation is now handled by _onAuthStatusChanged listener
    // This is important for Android where callbacks are async
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),

              // Icon with gradient background
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.phone_android_rounded,
                  size: 40,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Welcome',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Enter your phone number to continue. We\'ll send you a verification code.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 48),

              // Phone Input Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phone Number',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Country Code
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            AppConstants.defaultCountryCode,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Phone Input
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            focusNode: _focusNode,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(15),
                            ],
                            decoration: InputDecoration(
                              hintText: '98XXXXXXXX',
                              hintStyle: TextStyle(
                                color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                              ),
                              errorText: _phoneError,
                            ),
                            onChanged: (_) {
                              if (_phoneError != null) {
                                setState(() => _phoneError = null);
                              }
                            },
                            onFieldSubmitted: (_) => _validateAndSubmit(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Continue Button
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  final isLoading = authProvider.isLoading;

                  return FilledButton(
                    onPressed: isLoading ? null : _validateAndSubmit,
                    child: isLoading
                        ? SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Continue'),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Terms text
              Center(
                child: Text(
                  'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
