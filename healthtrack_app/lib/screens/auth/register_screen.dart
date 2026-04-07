import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../setup/profile_setup_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  void _next() {
    if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty ||
        _passwordCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields (password ≥ 6 chars)')));
      return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => ProfileSetupScreen(
        name:     _nameCtrl.text.trim(),
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent,
                     foregroundColor: AppColors.textPrimary),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create account',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                                 color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text('Step 1 of 2 — Basic info',
                style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 36),

              TextField(controller: _nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline, color: AppColors.textSecondary))),
              const SizedBox(height: 16),

              TextField(controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary))),
              const SizedBox(height: 16),

              TextField(controller: _passwordCtrl, obscureText: _obscure,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                               color: AppColors.textSecondary),
                    onPressed: () => setState(() => _obscure = !_obscure)))),
              const Spacer(),

              SizedBox(width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
                  child: const Text('Next →',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
            ],
          ),
        ),
      ),
    );
  }
}