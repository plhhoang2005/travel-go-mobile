import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/widgets/app_button.dart';
import '../../providers/auth_provider.dart';
import '../../../navigation/presentation/screens/main_navigation_shell.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final bool isResetPassword;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.isResetPassword = false,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _secondsRemaining = 59;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsRemaining = 59;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredOtp => _controllers.map((c) => c.text).join();

  Future<void> _handleVerify() async {
    final otp = _enteredOtp;
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập đủ 6 chữ số OTP'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.verifyOtp(otp, email: widget.email);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isResetPassword
              ? 'Xác thực thành công! Đã khôi phục tài khoản.'
              : 'Xác thực tài khoản thành công!'),
          backgroundColor: const Color(0xFF086C61),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationShell()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Mã xác thực không chính xác.'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _fillQuickDemoOtp() {
    const demo = '123456';
    for (int i = 0; i < 6; i++) {
      _controllers[i].text = demo[i];
    }
    _handleVerify();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF172422)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Brand Mark
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF086C61),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Xác thực mã OTP 📩',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF172422),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mã xác thực gồm 6 chữ số đã được gửi tới email:\n${widget.email}',
                style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF65726F)),
              ),
              const SizedBox(height: 16),

              // Demo quick tip chip
              GestureDetector(
                onTap: _fillQuickDemoOtp,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4F4F1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBAE6DE)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.touch_app_rounded, size: 18, color: Color(0xFF086C61)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mẹo kiểm thử: Chạm vào đây để tự động điền mã 123456',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF086C61),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // 6 Digits Box Row in Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFDFE6E4)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF112F2B).withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        return SizedBox(
                          width: 44,
                          height: 54,
                          child: TextField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF172422),
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: EdgeInsets.zero,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFDFE6E4)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF086C61),
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (val) {
                              if (val.isNotEmpty && index < 5) {
                                _focusNodes[index + 1].requestFocus();
                              } else if (val.isEmpty && index > 0) {
                                _focusNodes[index - 1].requestFocus();
                              }
                              if (_enteredOtp.length == 6) {
                                _handleVerify();
                              }
                            },
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 24),

                    // Countdown / Resend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: _secondsRemaining > 0 ? const Color(0xFF65726F) : const Color(0xFF086C61),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _secondsRemaining > 0
                              ? 'Gửi lại mã sau 00:${_secondsRemaining.toString().padLeft(2, '0')}'
                              : 'Chưa nhận được mã? ',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF65726F)),
                        ),
                        if (_secondsRemaining == 0)
                          GestureDetector(
                            onTap: _startTimer,
                            child: const Text(
                              'Gửi lại ngay',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF086C61),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              AppButton(
                label: 'Xác nhận & Hoàn tất',
                width: double.infinity,
                backgroundColor: const Color(0xFF086C61),
                isLoading: auth.isLoading,
                onPressed: _handleVerify,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
