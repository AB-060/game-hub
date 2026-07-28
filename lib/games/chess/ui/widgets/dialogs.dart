import 'package:flutter/material.dart';

import '../../models/chess_models.dart';
import 'piece_painter.dart';

Future<PieceType?> showPromotionDialog(BuildContext context, PieceColor color) {
  const options = [PieceType.queen, PieceType.rook, PieceType.bishop, PieceType.knight];
  return showDialog<PieceType>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF15152C),
        title: const Text("Promotion du pion"),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: options.map((type) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).pop(type),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: ChessPieceIcon(piece: ChessPiece(type, color), size: 44),
                ),
              ),
            );
          }).toList(),
        ),
      );
    },
  );
}

Future<void> showGameOverDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required VoidCallback onRematch,
  required VoidCallback onHome,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF15152C),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(subtitle, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onHome();
            },
            child: const Text("Accueil"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRematch();
            },
            child: const Text("Rejouer"),
          ),
        ],
      );
    },
  );
}
