import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../home/particle_background.dart';
import '../theme/app_colors.dart';

/// Un choix proposé dans une étape. Le toucher valide l'étape et enchaîne
/// automatiquement sur la suivante.
class WizardOption {
  final String label;
  final String? subtitle;
  final IconData? icon;

  /// Pastille emoji (thèmes du Memory) affichée à la place de l'icône.
  final String? emoji;

  /// Visuel sur mesure affiché en tête de l'option (pièce d'échecs,
  /// pastille de couleur du Ludo…).
  final Widget? leading;

  final bool selected;
  final VoidCallback onSelect;

  const WizardOption({
    required this.label,
    required this.selected,
    required this.onSelect,
    this.subtitle,
    this.icon,
    this.emoji,
    this.leading,
  });
}

/// Une étape du formulaire = une seule question, seule sur sa page.
class WizardStep {
  final String title;
  final String? hint;
  final List<WizardOption> options;

  /// Corps sur mesure (ex. les sièges du Ludo). Une étape personnalisée ne
  /// s'enchaîne pas toute seule : l'utilisateur valide avec le bouton. Le
  /// builder reçoit un callback pour redessiner l'étape après une
  /// modification, le wizard vivant dans sa propre route.
  final Widget Function(VoidCallback refresh)? custom;

  /// Dispose les options en grille plutôt qu'en liste (thèmes du Memory).
  final bool grid;

  const WizardStep({
    required this.title,
    this.hint,
    this.options = const [],
    this.custom,
    this.grid = false,
  });

  bool get isCustom => custom != null;
}

/// Formulaire de configuration présenté une question par page : l'utilisateur
/// touche un choix et passe directement à la question suivante, le dernier
/// choix lançant la partie.
///
/// Les étapes sont reconstruites à chaque sélection via [stepsBuilder], ce qui
/// permet à un jeu de faire dépendre ses questions des réponses précédentes
/// (le Morpion ne demande la difficulté que si l'on joue contre l'IA).
class SetupWizard extends StatefulWidget {
  final String gameTitle;
  final List<WizardStep> Function() stepsBuilder;

  /// Appelé une fois la dernière étape validée : lance la partie.
  final VoidCallback onComplete;

  /// Libellé du bouton de validation des étapes personnalisées.
  final String continueLabel;

  const SetupWizard({
    super.key,
    required this.gameTitle,
    required this.stepsBuilder,
    required this.onComplete,
    this.continueLabel = "Continuer",
  });

  @override
  State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  int _index = 0;
  bool _goingBack = false;

  /// Verrou le temps de l'animation d'enchaînement, pour éviter qu'un double
  /// appui ne saute une question.
  bool _advancing = false;

  void _select(WizardOption option) async {
    if (_advancing) return;
    setState(() => _advancing = true);
    option.onSelect();

    // Laisse voir le choix sélectionné avant d'enchaîner.
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    _advance();
  }

  void _advance() {
    // Les étapes peuvent avoir changé suite à la sélection.
    final steps = widget.stepsBuilder();
    if (_index >= steps.length - 1) {
      setState(() => _advancing = false);
      widget.onComplete();
      return;
    }
    setState(() {
      _goingBack = false;
      _index++;
      _advancing = false;
    });
  }

  void _back() {
    if (_index == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _goingBack = true;
      _index--;
    });
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.stepsBuilder();
    // Une réponse précédente a pu retirer des étapes (Morpion : passer en
    // « 2 joueurs » supprime la difficulté et le symbole).
    final index = _index.clamp(0, steps.length - 1);
    final step = steps[index];
    final isLast = index == steps.length - 1;

    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: kBg,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(widget.gameTitle),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _back,
          ),
        ),
        body: Stack(
          children: [
            const Positioned.fill(child: ParticleBackground()),
            SafeArea(
              child: Column(
                children: [
                  _progress(steps.length, index),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      // Par défaut l'AnimatedSwitcher empile ses enfants
                      // centrés : on garde les questions calées en haut pour
                      // que la mise en page ne saute pas d'une étape à
                      // l'autre selon le nombre d'options.
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          ...previous,
                          if (current != null) current,
                        ],
                      ),
                      transitionBuilder: (child, animation) {
                        final offset = Tween<Offset>(
                          begin: Offset(_goingBack ? -0.18 : 0.18, 0),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(position: offset, child: child),
                        );
                      },
                      child: _stepBody(step, index, isLast),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progress(int total, int index) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: List.generate(total, (i) {
                final done = i <= index;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    height: 4,
                    margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
                    decoration: BoxDecoration(
                      color: done ? kAccent : Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            "${index + 1}/$total",
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBody(WizardStep step, int index, bool isLast) {
    return SingleChildScrollView(
      key: ValueKey(index),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            step.title,
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          if (step.hint != null) ...[
            const SizedBox(height: 8),
            Text(
              step.hint!,
              style: GoogleFonts.poppins(fontSize: 13, color: kMuted, height: 1.4),
            ),
          ],
          const SizedBox(height: 28),
          if (step.isCustom)
            step.custom!(() => setState(() {}))
          else if (step.grid)
            _optionsGrid(step.options)
          else
            _optionsList(step.options),
          if (step.isCustom) ...[
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _advancing ? null : _advance,
              icon: Icon(isLast ? Icons.play_arrow_rounded : Icons.arrow_forward_rounded),
              label: Text(isLast ? "Lancer la partie" : widget.continueLabel),
            ),
          ],
        ],
      ),
    );
  }

  Widget _optionsList(List<WizardOption> options) {
    return Column(
      children: [
        for (final option in options) ...[
          _OptionCard(option: option, onTap: () => _select(option)),
          if (option != options.last) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _optionsGrid(List<WizardOption> options) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.95,
      children: options
          .map((o) => _OptionTile(option: o, onTap: () => _select(o)))
          .toList(),
    );
  }
}

/// Choix en pleine largeur : la carte principale du wizard.
class _OptionCard extends StatelessWidget {
  final WizardOption option;
  final VoidCallback onTap;

  const _OptionCard({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = option.selected;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: selected ? kAccent.withOpacity(0.16) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? kAccent : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            if (option.emoji != null) ...[
              Text(option.emoji!, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 14),
            ] else if (option.leading != null) ...[
              option.leading!,
              const SizedBox(width: 14),
            ] else if (option.icon != null) ...[
              Icon(option.icon, size: 22, color: selected ? kAccent : Colors.white38),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    option.label,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : Colors.white70,
                    ),
                  ),
                  if (option.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle!,
                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              color: selected ? kAccent : Colors.white24,
            ),
          ],
        ),
      ),
    );
  }
}

/// Choix compact en grille (thèmes du Memory).
class _OptionTile extends StatelessWidget {
  final WizardOption option;
  final VoidCallback onTap;

  const _OptionTile({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = option.selected;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? kAccent.withOpacity(0.16) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? kAccent : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (option.emoji != null)
              Text(option.emoji!, style: const TextStyle(fontSize: 26))
            else if (option.leading != null)
              option.leading!
            else if (option.icon != null)
              Icon(option.icon, size: 26, color: selected ? kAccent : Colors.white38),
            const SizedBox(height: 8),
            Text(
              option.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
