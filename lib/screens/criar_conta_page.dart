// Importa os componentes e estilos visuais do Flutter
import 'package:flutter/material.dart';

// Importa o modelo de usuário para verificar a permissão do e-mail mãe e traduzir cargos
import '../models/usuario.dart';
// Importa o serviço de API para cadastro de novos usuários
import '../services/api_service.dart';
// Importa o gerenciador da sessão ativa para validar o e-mail mãe conectado
import '../services/sessao.dart';
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
    // Impede qualquer tentativa caso o usuário logado não seja o e-mail mãe autorizado
    if (!(Sessao.instance.usuario?.podeCriarContas ?? false)) {
      setState(() {
        _erro =
            'Apenas a conta administradora (${Usuario.emailMae}) pode criar novas contas.';
      });
      return;
    }

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

      // Exibe notificação de confirmação no rodapé mantendo o administrador logado
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Conta $email (${Usuario.rotuloPerfil(_role)}) criada com sucesso.',
          ),
        ),
      );

      // Fecha a tela de cadastro e retorna para o painel da loja
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
    // Confere se o usuário conectado na sessão é o e-mail mãe autorizado a criar contas
    final autorizado = Sessao.instance.usuario?.podeCriarContas ?? false;

    // Estrutura principal da tela com barra de navegação superior
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar nova conta'),
        // Inclui o botão de alternar entre tema claro e tema escuro nesta tela
        actions: const [BotaoAlternarTema()],
      ),
      body: SafeArea(
        // Caso alguém acesse esta tela sem ser o e-mail mãe, exibe bloqueio informativo com botão Voltar
        child: !autorizado
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: context.cardSurface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(color: context.hairline),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Ícone circular de acesso restrito
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_outline_rounded,
                              size: 28,
                              color: AppColors.danger,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Título explicativo da restrição
                          Text(
                            'Acesso restrito',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: context.textStrong,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Descrição clara informando qual conta possui permissão
                          Text(
                            'Apenas a conta administradora (${Usuario.emailMae}) pode cadastrar novos usuários na loja.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.4,
                              color: context.textMuted,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Botão para fechar a tela e retornar
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Voltar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : Center(
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
                          // Subtítulo descritivo para cadastro interno da equipe
                          Text(
                            'Cadastre um colaborador com cargo, e-mail e senha.',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: context.textMuted,
                            ),
                          ),
                          const SizedBox(height: 22),
                          // Dropdown para seleção do cargo interno na loja (Vendedor, Gerente ou Proprietário)
                          DropdownButtonFormField<String>(
                            // Valor inicial selecionado no campo
                            initialValue: _role,
                            // Faz o seletor ocupar toda a largura horizontal disponível
                            isExpanded: true,
                            // Decoração visual com rótulo, ícone de crachá e texto explicativo dinâmico
                            decoration: InputDecoration(
                              // Rótulo do campo de seleção
                              labelText: 'Cargo na loja',
                              // Ícone ilustrativo de identificação profissional
                              prefixIcon: const Icon(Icons.badge_outlined),
                              // Exibe na parte inferior o resumo das permissões do cargo escolhido
                              helperText: switch (_role) {
                                // Resumo das permissões do Proprietário
                                'OWNER' =>
                                  'Acesso total: catálogo, estoque, exclusão e auditoria de saídas.',
                                // Resumo das permissões do Gerente
                                'USER' =>
                                  'Gestão operacional: cadastra/edita modelos e repõe estoque.',
                                // Resumo das permissões do Vendedor
                                _ =>
                                  'Atendimento: consulta catálogo, usa provador e registra vendas.',
                              },
                              // Permite até 2 linhas para a legenda de permissões não cortar em telas menores
                              helperMaxLines: 2,
                            ),
                            // Opções de cargos internos disponíveis para cadastro
                            items: const [
                              // Opção para Vendedor(a)
                              DropdownMenuItem(
                                value: 'SELLER',
                                child: Text('Vendedor(a)'),
                              ),
                              // Opção para Gerente
                              DropdownMenuItem(
                                value: 'USER',
                                child: Text('Gerente'),
                              ),
                              // Opção para Proprietário(a)
                              DropdownMenuItem(
                                value: 'OWNER',
                                child: Text('Proprietário(a)'),
                              ),
                            ],
                            // Atualiza o cargo selecionado no estado da tela
                            onChanged: (v) {
                              if (v != null) setState(() => _role = v);
                            },
                          ),
                          const SizedBox(height: 16),
                          // Campo de digitação de E-mail do novo colaborador
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'E-mail',
                              hintText: 'colaborador@loja.com',
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
                          // Campo de digitação da Senha inicial da nova conta
                          TextFormField(
                            controller: _senhaController,
                            obscureText: _ocultarSenha,
                            textInputAction: TextInputAction.next,
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
                          // Botão de texto para fechar o cadastro e retornar à tela anterior
                          TextButton(
                            onPressed: _salvando
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Voltar'),
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
