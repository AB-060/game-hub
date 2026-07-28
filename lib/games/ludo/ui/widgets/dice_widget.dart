import 'package:flutter/material.dart';

/// Dé animé : petite rotation/rebond à chaque changement de valeur.
class DiceWidget extends StatefulWidget {
  final int? value;
  final bool rolling;
  final VoidCallback? onTap;

  const DiceWidget({super.key, required this.value, required this.rolling, this.onTap});

  @override
  State<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<DiceWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  }

  @override
  void didUpdateWidget(covariant DiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const Map<int, List<bool>> _pipsLayout = {
    1: [false, false, false, true, false, false, false, false, false],
    2: [true, false, false, false, false, false, false, false, true],
    3: [true, false, false, false, true, false, false, false, true],
    4: [true, false, true, false, false, false, true, false, true],
    5: [true, false, true, false, true, false, true, false, true],
    6: [true, false, true, true, false, true, true, false, true],
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = (1 - _controller.value) * 0.6;
          return Transform.rotate(angle: angle, child: child);
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
          ),
          padding: const EdgeInsets.all(6),
          child: widget.rolling
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
                  ),
                )
              : GridView.count(
                  crossAxisCount: 3,
                  physics: const NeverScrollableScrollPhysics(),
                  children: List.generate(9, (i) {
                    final pips = _pipsLayout[widget.value ?? 0];
                    final show = pips != null && pips[i];
                    return Center(
                      child: show
                          ? Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Colors.black87,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    );
                  }),
                ),
        ),
      ),
    );
  }
}
