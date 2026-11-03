import 'package:flutter/material.dart';

import '../config/loja.dart';
import '../models/usuario.dart';
import '../screens/login_page.dart';
import '../services/api_service.dart';
import '../services/sessao.dart';
import '../theme/app_theme.dart';

class LogoLoja extends StatelessWidget {
  final double tamanho;
  final bool sombra;

  const LogoLoja({super.key, this.tamanho = 40, this.sombra = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        color: AppColors.brand,
        shape: BoxShape.circle,
        boxShadow: sombra
            ? [
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: 0.35),
                  blurRadius: tamanho * 0.3,
                  offset: Offset(0, tamanho * 0.1),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        Loja.logoAsset,
        width: tamanho,
        height: tamanho,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        semanticLabel: Loja.nomeCompleto,
        errorBuilder: (_, __, ___) => Center(
          child: Text(
            'LV',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: tamanho * 0.36,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão de conta do usuário exibido no canto superior direito das AppBars.
class MarcaAppBar extends StatelessWidget {
  const MarcaAppBar({super.key});

  Future<void> _editarNome(BuildContext context, Usuario? usuario) async {
    final controller = TextEditingController(text: usuario?.nome ?? '');
    final novoNome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Identificação do atendente',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Seu nome ou apelido',
            hintText: 'Ex.: Arthur Silva',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: ctx.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 42)),
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (novoNome != null && novoNome.trim().isNotEmpty) {
      Sessao.instance.atualizarNome(novoNome);
    }
  }

  void _sair(BuildContext context) {
    Sessao.instance.encerrar();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Usuario?>(
      valueListenable: Sessao.instance.usuarioNotifier,
      builder: (context, usuarioNotificado, _) {
        final usuario = usuarioNotificado ?? Sessao.instance.usuario;
        final iniciais = usuario?.iniciais ?? 'U';
        final nome = usuario?.nome ?? 'Conta conectada';
        final email = usuario?.email ?? 'Sessão ativa';

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: PopupMenuButton<String>(
            tooltip: 'Conta',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
            onSelected: (valor) {
              if (valor == 'editar_nome') {
                _editarNome(context, usuario);
              } else if (valor == 'sair') {
                _sair(context);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nome,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textStrong,
                      ),
                    ),
                    if (usuario?.perfil != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        usuario!.perfilRotulo,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: context.accent,
                        ),
                      ),
                    ],
                    Text(
                      email,
                      style: TextStyle(fontSize: 12, color: context.textMuted),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (ApiService.modoDemo
                                    ? AppColors.hazard
                                    : AppColors.success)
                                .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ApiService.modoDemo
                            ? 'Modo demonstração'
                            : 'Conectado à API',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: ApiService.modoDemo
                              ? AppColors.hazard
                              : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'editar_nome',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Alterar nome de exibição'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'sair',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Sair'),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.brand,
                child: Text(
                  iniciais,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
