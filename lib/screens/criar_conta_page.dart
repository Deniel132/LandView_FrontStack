// Importa os componentes e estilos visuais do Flutter
import 'package:flutter/material.dart';

// Importa o serviço de API para cadastro de novos usuários
import '../services/api_service.dart';
// Importa o tema e atalhos de cor do aplicativo
import '../theme/app_theme.dart';
// Importa faixas visuais de aviso e erro
import '../widgets/estados.dart';
// Importa o logotipo oficial da marca
import '../widgets/logo_loja.dart';

/// Tela de criação de nova conta de usuário no sistema.
/// Permite definir e-mail, senha com confirmação e o perfil de acesso (`SELLER`, `OWNER` ou `USER`).
/// Ao salvar com sucesso, envia `POST /api/user/` e retorna à tela de login já com o e-mail preenchido.
class CriarContaPage extends StatefulWidget {
  // Construtor constante da página
  const CriarContaPage({super.key});

  @override
  State<CriarContaPage> createState() => _CriarContaPageState();
}

class _CriarContaPageState extends State<CriarContaPage> {
  // Chave global para controle e validação de formulário
  final _formKey = GlobalKey<FormState>();

  // Controlador do campo de e-mail
  final _emailController = TextEditingController();

  // Controlador do campo de senha
  final _senhaController = TextEditingController();

  // Controlador do campo de confirmação da senha
  final _confirmarSenhaController = TextEditingController();

  // Controla a visibilidade da senha (oculta ou exibida)
  bool _ocultarSenha = true;

  // Controla a visibilidade da confirmação de senha
  bool _ocultarConfirmacao = true;

  // Flag indicadora de requisição de cadastro em andamento
  bool _salvando = false;

  // Perfil padrão selecionado para a nova conta (Vendedor)
  String _role = 'SELLER';

  // Mensagem de erro retornada pela API (ex: e-mail já existente)
  String? _erro;

  @override
  void dispose() {
    // Libera a memória ocupada pelos controladores de texto ao fechar a tela
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  /// Executa o fluxo de validação e envio dos dados para criação da conta na API
  Future<void> _criarConta() async {
    // Valida os campos de entrada do formulário
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Fecha o teclado virtual do dispositivo
    FocusScope.of(context).unfocus();

    // Ativa o estado de carregamento e limpa erros prévios
    setState(() {
      _salvando = true;
      _erro = null;
    });

    // Remove espaços nas pontas do e-mail
    final email = _emailController.text.trim();

    try {
      // Dispara requisição POST /api/user/ na API do FastAPI enviando e-mail, senha criptografada e role
      await ApiService.instance.criarConta(
        email,
        _senhaController.text,
        role: _role,
      );

      // Garante que a tela continua montada antes de interagir com a interface
      if (!mounted) return;

      // Exibe notificação de confirmação no rodapé
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conta criada com sucesso. Entre com seu e-mail e senha.'),
        ),
      );

      // Fecha a tela de cadastro e devolve o e-mail cadastrado para a tela de login
      Navigator.of(context).pop(email);
    } on ApiException catch (e) {
      // Em caso de falha (ex: e-mail já cadastrado - erro 409), captura e exibe na tela
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _erro = e.mensagem;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Detecta se está renderizando no modo escuro
    final isDark = context.isDark;

    // Estrutura principal da tela com barra de navegação superior
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: Center(
          // Permite rolagem vertical caso o teclado seja aberto
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            // Limita a largura máxima do cartão a 420px
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logotipo da loja no topo com diâmetro 72px
                  const LogoLoja(tamanho: 72, sombra: true),
                  const SizedBox(height: 22),
                  // Cartão com o formulário de cadastro
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: context.cardSurface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
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
                    // Formulário com validação
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Título "Nova conta"
                          Text(
                            'Nova conta',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: context.textStrong,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Subtítulo descritivo
                          Text(
                            'Informe seus dados para acessar o sistema.',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: context.textMuted,
                            ),
                          ),
                          const SizedBox(height: 22),
                          // Dropdown para seleção do perfil de acesso (Vendedor, Proprietário ou Usuário)
                          DropdownButtonFormField<String>(
                            initialValue: _role,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Perfil de acesso',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'SELLER',
                                child: Text('Vendedor(a)'),
                              ),
                              DropdownMenuItem(
                                value: 'OWNER',
                                child: Text('Proprietário(a)'),
                              ),
                              DropdownMenuItem(
                                value: 'USER',
                                child: Text('Usuário(a)'),
                              ),
                            ],
                            // Atualiza a role selecionada no estado
                            onChanged: (v) {
                              if (v != null) setState(() => _role = v);
                            },
                          ),
                          const SizedBox(height: 16),
                          // Campo de digitação de E-mail
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newUsername],
                            decoration: const InputDecoration(
                              labelText: 'E-mail',
                              hintText: 'voce@loja.com',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                            // Validação de formato de e-mail
                            validator: (value) {
                              final email = (value ?? '').trim();
                              if (email.isEmpty) return 'Informe o e-mail';
                              if (!RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(email)) {
                                return 'E-mail inválido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Campo de digitação da Senha
                          TextFormField(
                            controller: _senhaController,
                            obscureText: _ocultarSenha,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              helperText: 'Mínimo de 8 caracteres',
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
                            // Validação de comprimento mínimo de 8 caracteres
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Informe a senha';
                              }
                              if (value.length < 8) {
                                return 'Use pelo menos 8 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Campo de confirmação de Senha
                          TextFormField(
                            controller: _confirmarSenhaController,
                            obscureText: _ocultarConfirmacao,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _criarConta(),
                            decoration: InputDecoration(
                              labelText: 'Confirmar senha',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _ocultarConfirmacao
                                    ? 'Mostrar senha'
                                    : 'Ocultar senha',
                                icon: Icon(
                                  _ocultarConfirmacao
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _ocultarConfirmacao =
                                      !_ocultarConfirmacao,
                                ),
                              ),
                            ),
                            // Validação para checar se as duas senhas são idênticas
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Confirme sua senha';
                              }
                              if (value != _senhaController.text) {
                                return 'As senhas não conferem';
                              }
                              return null;
                            },
                          ),
                          // Faixa de erro caso a API rejeite a criação de conta
                          if (_erro != null) ...[
                            const SizedBox(height: 16),
                            FaixaAviso.erro(mensagem: _erro!),
                          ],
                          const SizedBox(height: 22),
                          // Botão principal de submissão do formulário
                          SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _salvando ? null : _criarConta,
                              child: _salvando
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Criar conta'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Botão de texto para retornar à tela de Login
                          TextButton(
                            onPressed: _salvando
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Voltar para o login'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
