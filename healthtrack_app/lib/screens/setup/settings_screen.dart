import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/user_provider.dart';
import '../../providers/food_provider.dart';
import '../../providers/weight_provider.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _fs  = FirestoreService();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  // Account
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl     = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  // Health profile
  late TextEditingController _weightCtrl;
  late TextEditingController _targetCtrl;
  late TextEditingController _calorieCtrl;
  late String _goal;

  // Notifications
  bool _dailyFoodReminder = true;
  bool _streakReminder    = true;
  bool _weeklyProgress    = true;

  bool _saving = false;

  final _goals = ['Lose Weight', 'Stay Fit', 'Build Muscle'];

  @override
  void initState() {
    super.initState();
    final user   = context.read<UserProvider>().user!;
    _nameCtrl    = TextEditingController(text: user.name);
    _emailCtrl   = TextEditingController(text: user.email);
    _weightCtrl  = TextEditingController(
      text: user.currentWeight.toStringAsFixed(1));
    _targetCtrl  = TextEditingController(
      text: user.targetWeight.toStringAsFixed(1));
    _calorieCtrl = TextEditingController(
      text: user.dailyCalorieGoal.toStringAsFixed(0));
    _goal = user.goal;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _weightCtrl.dispose();
    _targetCtrl.dispose();
    _calorieCtrl.dispose();
    super.dispose();
  }

  // ── Avatar helpers ───────────────────────────────────────
  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color _avatarColor(String name) {
    final colors = [
      AppColors.primary,
      AppColors.caloriePurple,
      AppColors.warning,
      AppColors.success,
      Colors.blueAccent,
      Colors.pinkAccent,
    ];
    return colors[
      name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0];
  }

  // ── Save profile ─────────────────────────────────────────
  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      final user    = context.read<UserProvider>().user!;
      final updated = UserModel(
        uid:              user.uid,
        email:            user.email,
        name:             _nameCtrl.text.trim(),
        goal:             _goal,
        currentWeight:    double.tryParse(_weightCtrl.text)
                          ?? user.currentWeight,
        targetWeight:     double.tryParse(_targetCtrl.text)
                          ?? user.targetWeight,
        heightCm:         user.heightCm,
        age:              user.age,
        gender:           user.gender,
        dailyCalorieGoal: double.tryParse(_calorieCtrl.text)
                          ?? user.dailyCalorieGoal,
        streak:           user.streak,
        lastActiveDate:   user.lastActiveDate,
        healthScore:      user.healthScore,
      );

      await _fs.updateUserProfile(updated);
      if (!mounted) return;
      context.read<UserProvider>().setUser(updated);
      _showSnack('Profile saved!', AppColors.success);
      Navigator.pop(context);
    } catch (e) {
      _showSnack('Failed to save: $e', AppColors.danger);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Change password ──────────────────────────────────────
  Future<void> _changePassword() async {
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      _showSnack('New passwords do not match.', AppColors.danger);
      return;
    }
    if (_newPassCtrl.text.length < 6) {
      _showSnack('Password must be at least 6 characters.', AppColors.danger);
      return;
    }
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser!;
      final credential   = EmailAuthProvider.credential(
        email:    firebaseUser.email!,
        password: _currentPassCtrl.text,
      );
      await firebaseUser.reauthenticateWithCredential(credential);
      await firebaseUser.updatePassword(_newPassCtrl.text);
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      if (mounted) {
        Navigator.pop(context);
        _showSnack('Password changed successfully!', AppColors.success);
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(
        e.code == 'wrong-password'
          ? 'Current password is incorrect.'
          : 'Error: ${e.message}',
        AppColors.danger,
      );
    }
  }

  // ── Logout ───────────────────────────────────────────────
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out',
          style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              context.read<UserProvider>().clear();
              context.read<FoodProvider>().clear();
              context.read<WeightProvider>().clear();
              await AuthService().logout();
            },
            child: const Text('Log Out',
              style: TextStyle(
                color:      AppColors.danger,
                fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Change password dialog ───────────────────────────────
  void _showChangePasswordDialog() {
    bool ob1 = true, ob2 = true, ob3 = true;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
          title: const Text('Change Password',
            style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PassField(
                ctrl:     _currentPassCtrl,
                label:    'Current password',
                obscure:  ob1,
                onToggle: () => setDialogState(() => ob1 = !ob1),
              ),
              const SizedBox(height: 12),
              _PassField(
                ctrl:     _newPassCtrl,
                label:    'New password',
                obscure:  ob2,
                onToggle: () => setDialogState(() => ob2 = !ob2),
              ),
              const SizedBox(height: 12),
              _PassField(
                ctrl:     _confirmPassCtrl,
                label:    'Confirm new password',
                obscure:  ob3,
                onToggle: () => setDialogState(() => ob3 = !ob3),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: _changePassword,
              child: const Text('Update',
                style: TextStyle(
                  color:      AppColors.primary,
                  fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:         Text(msg),
        backgroundColor: color));
  }

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user        = context.watch<UserProvider>().user!;
    final avatarColor = _avatarColor(user.name);
    final initials    = _initials(user.name);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Settings',
          style: TextStyle(
            color:      AppColors.textPrimary,
            fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveProfile,
            child: _saving
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color:       AppColors.primary))
              : const Text('Save',
                  style: TextStyle(
                    color:      AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize:   16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Avatar ───────────────────────────────────────
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width:  90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape:  BoxShape.circle,
                      color:  avatarColor.withValues(alpha: 0.2),
                      border: Border.all(
                        color: avatarColor, width: 2.5),
                    ),
                    child: Center(
                      child: Text(initials,
                        style: TextStyle(
                          color:      avatarColor,
                          fontSize:   34,
                          fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(user.name,
                    style: const TextStyle(
                      color:      AppColors.textPrimary,
                      fontSize:   20,
                      fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(user.email,
                    style: const TextStyle(
                      color:   AppColors.textSecondary,
                      fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20)),
                    child: Text(user.goal,
                      style: const TextStyle(
                        color:      AppColors.primary,
                        fontSize:   12,
                        fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),

            // ── ACCOUNT ──────────────────────────────────────
            const _SectionHeader('Account'),
            _SettingsCard(children: [
              _FieldTile(
                icon:       Icons.person_outline,
                label:      'Full Name',
                controller: _nameCtrl,
                type:       TextInputType.name,
              ),
              const _CardDivider(),
              _FieldTile(
                icon:       Icons.email_outlined,
                label:      'Email',
                controller: _emailCtrl,
                type:       TextInputType.emailAddress,
                readOnly:   true,
                hint:       'Cannot be changed',
              ),
              const _CardDivider(),
              _TapTile(
                icon:  Icons.lock_outline,
                label: 'Change Password',
                onTap: _showChangePasswordDialog,
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                  size:  18),
              ),
            ]),
            const SizedBox(height: 24),

            // ── HEALTH PROFILE ────────────────────────────────
            const _SectionHeader('Health Profile'),
            _SettingsCard(children: [
              _FieldTile(
                icon:       Icons.monitor_weight_outlined,
                label:      'Current Weight',
                controller: _weightCtrl,
                type: const TextInputType.numberWithOptions(
                  decimal: true),
                suffix: 'kg',
              ),
              const _CardDivider(),
              _FieldTile(
                icon:       Icons.track_changes,
                label:      'Target Weight',
                controller: _targetCtrl,
                type: const TextInputType.numberWithOptions(
                  decimal: true),
                suffix: 'kg',
              ),
              const _CardDivider(),
              _FieldTile(
                icon:       Icons.local_fire_department_outlined,
                label:      'Daily Calorie Goal',
                controller: _calorieCtrl,
                type:       TextInputType.number,
                suffix:     'kcal',
              ),
              const _CardDivider(),
              // Fitness goal selector
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                        child: const Icon(
                          Icons.flag_outlined,
                          color: AppColors.primary,
                          size:  18),
                      ),
                      const SizedBox(width: 14),
                      const Text('Fitness Goal',
                        style: TextStyle(
                          color:    AppColors.textSecondary,
                          fontSize: 14)),
                    ]),
                    const SizedBox(height: 12),
                    Row(
                      children: _goals.map((g) => Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _goal = g),
                          child: AnimatedContainer(
                            duration:
                              const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              vertical: 10),
                            decoration: BoxDecoration(
                              color: _goal == g
                                ? AppColors.primary
                                : AppColors.surface,
                              borderRadius:
                                BorderRadius.circular(10)),
                            child: Text(g,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _goal == g
                                  ? Colors.black
                                  : AppColors.textSecondary,
                                fontWeight: _goal == g
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                                fontSize: 11)),
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 24),

            // ── NOTIFICATIONS ─────────────────────────────────
            const _SectionHeader('Notifications'),
            _SettingsCard(children: [
              _ToggleTile(
                icon:      Icons.restaurant_menu,
                label:     'Daily food reminder',
                subtitle:  'Reminds you to log your meals',
                value:     _dailyFoodReminder,
                onChanged: (v) =>
                  setState(() => _dailyFoodReminder = v),
              ),
              const _CardDivider(),
              _ToggleTile(
                icon:      Icons.local_fire_department,
                label:     'Streak reminder',
                subtitle:  'Alert if you haven\'t opened the app by evening',
                value:     _streakReminder,
                onChanged: (v) =>
                  setState(() => _streakReminder = v),
              ),
              const _CardDivider(),
              _ToggleTile(
                icon:      Icons.bar_chart,
                label:     'Weekly progress summary',
                subtitle:  'Get a summary every Sunday',
                value:     _weeklyProgress,
                onChanged: (v) =>
                  setState(() => _weeklyProgress = v),
              ),
            ]),
            const SizedBox(height: 32),

            // ── LOGOUT ────────────────────────────────────────
            SizedBox(
              width:  double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _confirmLogout,
                icon: const Icon(
                  Icons.logout,
                  color: AppColors.danger),
                label: const Text('Log Out',
                  style: TextStyle(
                    color:      AppColors.danger,
                    fontWeight: FontWeight.bold,
                    fontSize:   16)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Reusable widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text,
      style: const TextStyle(
        color:         AppColors.textSecondary,
        fontSize:      13,
        fontWeight:    FontWeight.w600,
        letterSpacing: 0.5)),
  );
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color:        AppColors.card,
      borderRadius: BorderRadius.circular(16)),
    child: Column(children: children),
  );
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();
  @override
  Widget build(BuildContext context) => const Divider(
    color: AppColors.surface, height: 1, indent: 56);
}

class _FieldTile extends StatelessWidget {
  final IconData              icon;
  final String                label;
  final TextEditingController controller;
  final TextInputType         type;
  final String                suffix;
  final bool                  readOnly;
  final String                hint;

  const _FieldTile({
    required this.icon,
    required this.label,
    required this.controller,
    required this.type,
    this.suffix   = '',
    this.readOnly = false,
    this.hint     = '',
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: 16, vertical: 4),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color:        AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: TextField(
          controller:   controller,
          keyboardType: type,
          readOnly:     readOnly,
          style: TextStyle(
            color: readOnly
              ? AppColors.textSecondary
              : AppColors.textPrimary,
            fontSize: 14),
          decoration: InputDecoration(
            labelText:  label,
            hintText:   hint.isNotEmpty ? hint : null,
            hintStyle:  const TextStyle(
              color:    AppColors.textSecondary,
              fontSize: 12),
            suffixText:  suffix,
            suffixStyle: const TextStyle(
              color:    AppColors.textSecondary,
              fontSize: 13),
            filled:         false,
            border:         InputBorder.none,
            enabledBorder:  InputBorder.none,
            focusedBorder:  InputBorder.none,
            disabledBorder: InputBorder.none,
          ),
        ),
      ),
    ]),
  );
}

class _TapTile extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  final Widget       trailing;

  const _TapTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16, vertical: 16),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color:        AppColors.primary.withValues(alpha:  0.1),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(label,
            style: const TextStyle(
              color:    AppColors.textPrimary,
              fontSize: 14))),
        trailing,
      ]),
    ),
  );
}

class _ToggleTile extends StatelessWidget {
  final IconData           icon;
  final String             label;
  final String             subtitle;
  final bool               value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: 16, vertical: 12),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color:        AppColors.primary.withValues(alpha:  0.1),
          borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
              style: const TextStyle(
                color:    AppColors.textPrimary,
                fontSize: 14)),
            const SizedBox(height: 2),
            Text(subtitle,
              style: const TextStyle(
                color:    AppColors.textSecondary,
                fontSize: 11)),
          ],
        ),
      ),
      Switch(
        value:              value,
        onChanged:          onChanged,
        activeThumbColor:        AppColors.primary,
        inactiveTrackColor: AppColors.surface,
      ),
    ]),
  );
}

class _PassField extends StatelessWidget {
  final TextEditingController ctrl;
  final String                label;
  final bool                  obscure;
  final VoidCallback          onToggle;

  const _PassField({
    required this.ctrl,
    required this.label,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller:  ctrl,
    obscureText: obscure,
    style: const TextStyle(color: AppColors.textPrimary),
    decoration: InputDecoration(
      labelText: label,
      suffixIcon: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_off : Icons.visibility,
          color: AppColors.textSecondary,
          size:  18),
        onPressed: onToggle,
      ),
    ),
  );
}