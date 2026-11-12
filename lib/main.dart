// Importa os componentes e widgets da biblioteca visual Material Design do Flutter
import 'package:flutter/material.dart';
// Importa o painel principal com Navbar exibido quando o usuário já está autenticado
import 'screens/navegacao_page.dart';
// Importa a tela inicial de autenticação/login
import 'screens/login_page.dart';
// Importa o serviço gerenciador da sessão ativa, token e persistência no disco
import 'services/sessao.dart';
// Importa as configurações globais de tema visual claro e escuro
import 'theme/app_theme.dart';

/// Ponto de entrada principal da aplicação Flutter.
void main() async {
  // Garante que a infraestrutura de bindings do Flutter esteja inicializada antes de operações assíncronas
  WidgetsFlutterBinding.ensureInitialized();

  // Restaura a sessão salva no armazenamento persistente (resiste a F5 e recarregamento da página)
  await Sessao.instance.restaurar();

  // Configura a ação global a ser executada caso o servidor invalide a sessão (erro 401)
  Sessao.instance.aoExpirar = () {
    // Redireciona imediatamente para a tela de login limpando todo o histórico de navegação anterior
    MyApp.navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage(sessaoExpirada: true)),
      (_) => false,
    );
  };

  // Inicializa o Flutter e monta a árvore de widgets a partir do widget raiz MyApp
  runApp(const MyApp());
}

/// Widget raiz da aplicação que gerencia o MaterialApp, as rotas e a troca dinâmica de tema claro/escuro.
class MyApp extends StatelessWidget {
  // Construtor constante do widget raiz
  const MyApp({super.key});

  /// Notificador reativo estático para alternar entre os modos de tema claro (light) e escuro (dark)
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

  /// Chave global do navegador que permite transições de tela sem depender da passagem direta de BuildContext
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // Constrói a interface reagindo a qualquer mudança de valor em themeNotifier
    return ValueListenableBuilder<ThemeMode>(
      // Ouve as mudanças no notificador de tema
      valueListenable: themeNotifier,
      // Reconstrói a árvore com o modo de tema atualizado
      builder: (_, modo, __) => MaterialApp(
        // Título da aba do navegador ou identificação do aplicativo
        title: 'LandView Stock',
        // Oculta a faixa de depuração "DEBUG" no canto superior direito
        debugShowCheckedModeBanner: false,
        // Oculta a barra de rolagem flutuante ao lado do container central mantendo a rolagem normal
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          scrollbars: false,
        ),
        // Associa a chave global de navegação
        navigatorKey: navigatorKey,
        // Aplica o tema visual claro padrão
        theme: AppTheme.light(),
        // Aplica o tema visual escuro padrão
        darkTheme: AppTheme.dark(),
        // Define o modo atual (Light ou Dark)
        themeMode: modo,
        // Se já houver sessão salva (F5), entra direto na navegação com Navbar; caso contrário, vai para o Login
        home: Sessao.instance.logado ? const NavegacaoPage() : const LoginPage(),
      ),
    );
  }
}
