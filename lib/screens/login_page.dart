import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/contato_loja.dart';
import '../widgets/logo_loja.dart';
import 'dashboard_page.dart';
import 'criar_conta_page.dart';

/// Primeira tela do app. Envia e-mail e senha para a API e guarda o token
/// retornado na sessão para acompanhar as requisições seguintes.
class LoginPage extends StatefulWidget {
  /// Verdadeiro quando o usuário foi mandado de volta porque a API recusou o token.
  final bool sessaoExpirada;

  const LoginPage({super.key, this.sessaoExpirada = false});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(
    text: ApiService.modoDemo ? 'cliente@loja.com' : '',
  );
  final _senhaController = TextEditingController(
    text: ApiService.modoDemo ? 'demonstracao' : '',
  );

  bool _ocultarSenha = true;
  bool _entrando = false;
  String? _erro;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _entrando = true;
      _erro = null;
    });

    try {
      await ApiService.instance.login(
        _emailController.text.trim(),
        _senhaController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _entrando = false;
        _erro = e.mensagem;
      });
    }
  }

  Future<void> _abrirCriarConta() async {
    final email = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const CriarContaPage()));
    if (!mounted || email == null) return;
    setState(() {
      _emailController.text = email;
      _senhaController.clear();
      _erro = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Marca(),
                      const SizedBox(height: 28),
                      if (widget.sessaoExpirada) ...[
                        const _Faixa(
                          mensagem: 'Sua sessão expirou. Entre novamente.',
                          cor: AppColors.hazard,
                          icone: Icons.lock_clock_outlined,
                        ),
                        const SizedBox(height: 14),
                      ],
                      Container(
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                        decoration: BoxDecoration(
                          color: context.cardSurface,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLg,
                          ),
                          border: Border.all(color: context.hairline),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.3 : 0.07,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Entrar',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                  color: context.textStrong,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Acesse com a conta da loja.',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: context.textMuted,
                                ),
                              ),
                              const SizedBox(height: 22),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                decoration: const InputDecoration(
                                  labelText: 'E-mail',
                                  hintText: 'voce@loja.com',
                                  prefixIcon: Icon(Icons.mail_outline_rounded),
                                ),
                                validator: (v) {
                                  final texto = (v ?? '').trim();
                                  if (texto.isEmpty) return 'Informe o e-mail';
                                  if (!RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                  ).hasMatch(texto)) {
                                    return 'E-mail inválido';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _senhaController,
                                obscureText: _ocultarSenha,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) => _entrar(),
                                decoration: InputDecoration(
                                  labelText: 'Senha',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                  ),
                                  suffixIcon: IconButton(
                                    tooltip: _ocultarSenha
                                        ? 'Mostrar senha'
                                        : 'Ocultar senha',
                                    icon: Icon(
                                      _ocultarSenha
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () => setState(
                                      () => _ocultarSenha = !_ocultarSenha,
                                    ),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Informe a senha'
                                    : null,
                              ),
                              if (_erro != null) ...[
                                const SizedBox(height: 16),
                                _Faixa(
                                  mensagem: _erro!,
                                  cor: AppColors.danger,
                                  icone: Icons.error_outline_rounded,
                                ),
                              ],
                              const SizedBox(height: 22),
                              SizedBox(
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _entrando ? null : _entrar,
                                  child: _entrando
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Entrar'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _entrando ? null : _abrirCriarConta,
                                child: const Text('Criar uma conta'),
                              ),
                              if (ApiService.modoDemo) ...[
                                const SizedBox(height: 14),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      size: 16,
                                      color: context.textMuted,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Modo demonstração: qualquer e-mail válido e qualquer senha funcionam.',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          height: 1.35,
                                          color: context.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Acesso restrito à equipe da loja.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const ContatoCompacto(),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: 21,
                ),
                tooltip: isDark ? 'Usar tema claro' : 'Usar tema escuro',
                onPressed: () {
                  MyApp.themeNotifier.value = isDark
                      ? ThemeMode.light
                      : ThemeMode.dark;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const LogoLoja(tamanho: 84, sombra: true),
        const SizedBox(height: 18),
        Text(
          'LandView Stock',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            color: context.textStrong,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Artigos Esportivos',
          style: TextStyle(fontSize: 13.5, color: context.textMuted),
        ),
      ],
    );
  }
}

class _Faixa extends StatelessWidget {
  final String mensagem;
  final Color cor;
  final IconData icone;

  const _Faixa({
    required this.mensagem,
    required this.cor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 20, color: cor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensagem,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: context.textStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
