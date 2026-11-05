// Importa os componentes e estilos visuais do Flutter
import 'package:flutter/material.dart';
// Importa o aplicativo principal para alternar tema e acessar navegadores
import '../main.dart';
// Importa o serviço de API para autenticação
import '../services/api_service.dart';
// Importa o tema e atalhos de cor da aplicação
import '../theme/app_theme.dart';
// Importa os componentes de rodapé da loja
import '../widgets/contato_loja.dart';
// Importa os widgets de faixas de erro e aviso
import '../widgets/estados.dart';
// Importa o logotipo da marca
import '../widgets/logo_loja.dart';
// Importa a tela de cadastro/criação de conta
import 'criar_conta_page.dart';
// Importa o dashboard principal da loja
import 'dashboard_page.dart';

/// Tela de entrada (Login) do aplicativo.
/// Coleta e-mail e senha do atendente/vendedor, envia para a rota `POST /api/user/login` do FastAPI
/// e salva o token Bearer na sessão antes de redirecionar para o Dashboard da loja.
class LoginPage extends StatefulWidget {
  /// Verdadeiro quando o usuário foi deslogado automaticamente por token expirado (erro 401)
  final bool sessaoExpirada;

  /// Construtor com valor padrão de sessão não expirada
  const LoginPage({super.key, this.sessaoExpirada = false});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Chave global para validação do formulário de login
  final _formKey = GlobalKey<FormState>();

  // Controlador do campo de e-mail
  final _emailController = TextEditingController();

  // Controlador do campo de senha
  final _senhaController = TextEditingController();

  // Controla se a senha digitada deve ficar oculta (com pontinhos) ou visível
  bool _ocultarSenha = true;

  // Flag que indica se a requisição de login está em andamento (mostra spinner)
  bool _entrando = false;

  // Mensagem de erro retornada pela API caso a autenticação falhe
  String? _erro;

  @override
  void dispose() {
    // Libera a memória ocupada pelos controladores de texto ao descartar a tela
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  /// Processa a tentativa de login disparada pelo formulário
  Future<void> _entrar() async {
    // Se o formulário tiver erros de validação (e-mail vazio ou inválido), cancela o envio
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Fecha o teclado virtual do dispositivo
    FocusScope.of(context).unfocus();

    // Ativa o estado de carregamento e limpa mensagens de erro anteriores
    setState(() {
      _entrando = true;
      _erro = null;
    });

    try {
      // Dispara a requisição HTTP de login enviando e-mail e senha criptografada
      await ApiService.instance.login(
        _emailController.text.trim(),
        _senhaController.text,
      );

      // Garante que o widget ainda está montado na árvore antes de navegar
      if (!mounted) return;

      // Navega para o Dashboard substituindo a tela de login na pilha de rotas
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } on ApiException catch (e) {
      // Captura falhas retornadas pela API (ex: credenciais incorretas)
      if (!mounted) return;
      setState(() {
        _entrando = false;
        _erro = e.mensagem;
      });
    }
  }

  /// Abre a tela de cadastro e, caso uma nova conta seja criada com sucesso, preenche o e-mail no login
  Future<void> _abrirCriarConta() async {
    // Navega para CriarContaPage aguardando o e-mail cadastrado como retorno
    final email = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const CriarContaPage()));

    // Se retornou com um e-mail válido, preenche o campo de e-mail e foca na senha
    if (!mounted || email == null) return;
    setState(() {
      _emailController.text = email;
      _senhaController.clear();
      _erro = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Detecta se o aplicativo está rodando em tema escuro
    final isDark = context.isDark;

    // Estrutura principal com Scaffold
    return Scaffold(
      body: SafeArea(
        // Pilha que sobrepõe o botão de alternância de tema no topo direito
        child: Stack(
          children: [
            // Centraliza o cartão de login na tela
            Center(
              // Permite rolagem suave em telas menores ou ao abrir o teclado virtual
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 32,
                ),
                // Limita a largura máxima do formulário a 420px para não esticar em monitores largos
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cabeçalho da marca com o logotipo circular grande
                      const _Marca(),
                      // Espaçamento de 28px
                      const SizedBox(height: 28),
                      // Se a sessão expirou anteriormente, exibe alerta explicativo no topo
                      if (widget.sessaoExpirada) ...[
                        const FaixaAviso(
                          mensagem: 'Sua sessão expirou. Entre novamente.',
                          cor: AppColors.hazard,
                          icone: Icons.lock_clock_outlined,
                        ),
                        const SizedBox(height: 14),
                      ],
                      // Cartão do formulário com cantos arredondados e sombra elegante
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
                        // Formulário com validação integrada
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Título "Entrar"
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
                              // Subtítulo descritivo
                              Text(
                                'Acesse o painel e o catálogo da loja.',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: context.textMuted,
                                ),
                              ),
                              const SizedBox(height: 22),
                              // Campo de digitação de E-mail
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
                                // Validador de formato de e-mail com regex
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
                              // Campo de digitação de Senha
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
                                  // Botão de alternar visualização da senha (olho aberto/fechado)
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
                                // Validador de campo obrigatório para a senha
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Informe a senha'
                                    : null,
                              ),
                              // Exibe faixa vermelha caso a API retorne erro no login
                              if (_erro != null) ...[
                                const SizedBox(height: 16),
                                FaixaAviso.erro(mensagem: _erro!),
                              ],
                              const SizedBox(height: 22),
                              // Botão principal de submissão do Login
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
                              // Botão de texto para navegação até a tela de criação de conta
                              TextButton(
                                onPressed: _entrando ? null : _abrirCriarConta,
                                child: const Text('Criar uma conta'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Mensagem de rodapé sobre o acesso restrito
                      Text(
                        'Acesso restrito à equipe da loja.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Identificação institucional compacta da loja
                      const ContatoCompacto(),
                    ],
                  ),
                ),
              ),
            ),
            // Botão fixado no topo direito para alternar entre tema claro e tema escuro
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
                  // Alterna o valor global do notificador de tema
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

/// Componente visual do cabeçalho da marca com o logotipo e o título institucional
class _Marca extends StatelessWidget {
  const _Marca();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Logotipo grande com diâmetro 84px e sombra elegante
        const LogoLoja(tamanho: 84, sombra: true),
        const SizedBox(height: 18),
        // Nome da marca em destaque tipográfico
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
        // Subtítulo descritivo da atividade
        Text(
          'Artigos Esportivos · Provador & Estoque',
          style: TextStyle(fontSize: 13.5, color: context.textMuted),
        ),
      ],
    );
  }
}
