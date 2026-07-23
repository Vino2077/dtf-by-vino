import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/login_controller.dart';
import '../services/auth_service.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginController _controller;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = LoginController(
      context.read<AuthRepository>(),
      context.read<AuthService>(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Заполни почту и пароль');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await _controller.login(email, password);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _loading = false;
        _error = _controller.failure?.message ?? 'Не удалось войти';
      });
    }
  }

  void _showManualTokenDialog() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Войти по токену',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'На сайте dtf.ru: Профиль → Настройки → внизу страницы '
              '«Инструменты для разработчика» — там будет токен для входа.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(color: Colors.white, fontSize: 12),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Вставь токен...',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: AppColors.bgCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final tok = ctrl.text.trim();
                Navigator.pop(context);
                if (tok.isEmpty) return;
                setState(() {
                  _loading = true;
                  _error = null;
                });
                final valid = await _controller.saveValidatedToken(tok);
                if (!mounted) return;
                if (valid) {
                  Navigator.pop(context, true);
                } else {
                  setState(() {
                    _loading = false;
                    _error = _controller.failure?.message ?? 'Токен не подошёл';
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
              ),
              child: Text('Войти'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.grey),
    filled: true,
    fillColor: AppColors.bgCard,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Войти в DTF', style: TextStyle(color: AppColors.textPrimary)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Почта',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: _fieldDecoration('email@example.com'),
              ),
              const SizedBox(height: 16),
              Text(
                'Пароль',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                style: TextStyle(color: AppColors.textPrimary),
                onSubmitted: (_) => _submit(),
                decoration: _fieldDecoration('Пароль').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('Войти'),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _loading ? null : _showManualTokenDialog,
                  child: Text(
                    'Войти по токену',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
