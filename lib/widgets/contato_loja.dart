import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/loja.dart';
import '../theme/app_theme.dart';
import 'logo_loja.dart';

Future<void> abrirOuCopiar(
  BuildContext context,
  Uri uri, {
  required String copiar,
  required String avisoCopia,
}) async {
  var abriu = false;
  try {
    abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    abriu = false;
  }
  if (abriu || !context.mounted) return;
  await copiarTexto(context, copiar, avisoCopia);
}

Future<void> copiarTexto(
  BuildContext context,
  String texto,
  String aviso,
) async {
  await Clipboard.setData(ClipboardData(text: texto));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(aviso), duration: const Duration(seconds: 2)),
    );
}

Future<void> _abrirInstagram(BuildContext context) => abrirOuCopiar(
  context,
  Uri.parse(Loja.instagramUrl),
  copiar: Loja.instagram,
  avisoCopia: 'Instagram copiado: ${Loja.instagram}',
);

Future<void> _ligar(BuildContext context) => abrirOuCopiar(
  context,
  Uri(scheme: 'tel', path: Loja.telefoneLink),
  copiar: Loja.telefone,
  avisoCopia: 'Telefone copiado: ${Loja.telefone}',
);

class RodapeContato extends StatelessWidget {
  const RodapeContato({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: context.cardSurface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: context.hairline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Row(
                  children: [
                    const LogoLoja(tamanho: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fale com a loja',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: context.textStrong,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Loja.nomeCompleto,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: context.hairline),
              _LinhaContato(
                icone: Icons.alternate_email_rounded,
                rotulo: 'Instagram',
                valor: Loja.instagram,
                acao: Icons.open_in_new_rounded,
                dica: 'Abrir o Instagram da loja',
                aoTocar: () => _abrirInstagram(context),
              ),
              Divider(color: context.hairline),
              _LinhaContato(
                icone: Icons.call_outlined,
                rotulo: 'Telefone',
                valor: Loja.telefone,
                acao: Icons.call_made_rounded,
                dica: 'Ligar para a loja',
                aoTocar: () => _ligar(context),
              ),
              Divider(color: context.hairline),
              _LinhaContato(
                icone: Icons.location_on_outlined,
                rotulo: 'Endereço',
                valor: Loja.endereco,
                acao: Icons.copy_rounded,
                dica: 'Copiar o endereço',
                aoTocar: () =>
                    copiarTexto(context, Loja.endereco, 'Endereço copiado.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '${Loja.produto} · Projeto Automatize',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: context.textMuted),
        ),
      ],
    );
  }
}

class _LinhaContato extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final String valor;
  final IconData acao;
  final String dica;
  final VoidCallback aoTocar;

  const _LinhaContato({
    required this.icone,
    required this.rotulo,
    required this.valor,
    required this.acao,
    required this.dica,
    required this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: dica,
      child: InkWell(
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icone, size: 19, color: context.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rotulo,
                      style: TextStyle(fontSize: 12, color: context.textMuted),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      valor,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: context.textStrong,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(acao, size: 18, color: context.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class ContatoCompacto extends StatelessWidget {
  const ContatoCompacto({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        _LinkCompacto(
          icone: Icons.alternate_email_rounded,
          texto: Loja.instagram,
          aoTocar: () => _abrirInstagram(context),
        ),
        _LinkCompacto(
          icone: Icons.call_outlined,
          texto: Loja.telefone,
          aoTocar: () => _ligar(context),
        ),
      ],
    );
  }
}

class _LinkCompacto extends StatelessWidget {
  final IconData icone;
  final String texto;
  final VoidCallback aoTocar;

  const _LinkCompacto({
    required this.icone,
    required this.texto,
    required this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: aoTocar,
      style: TextButton.styleFrom(
        foregroundColor: context.textMuted,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icone, size: 16),
      label: Text(
        texto,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
      ),
    );
  }
}
