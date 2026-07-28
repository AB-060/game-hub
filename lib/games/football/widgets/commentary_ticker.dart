import 'package:flutter/material.dart';

import '../models/match_models.dart';

/// Ticker affichant le dernier commentaire, avec une transition animée à
/// chaque nouvel évènement.
class CommentaryTicker extends StatelessWidget {
  final MatchEvent? latest;

  const CommentaryTicker({super.key, required this.latest});

  Color _colorFor(MatchEventType? type) {
    switch (type) {
      case MatchEventType.goal:
        return Colors.greenAccent;
      case MatchEventType.saved:
        return Colors.cyanAccent;
      case MatchEventType.yellowCard:
        return Colors.amberAccent;
      case MatchEventType.redCard:
        return Colors.redAccent;
      default:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(latest?.hashCode ?? 0),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          latest == null ? " " : "${latest!.minute}' — ${latest!.text}",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _colorFor(latest?.type),
          ),
        ),
      ),
    );
  }
}
