// instrument_shell.dart
//
// 3-destination Floating Glass Dock shell wrapping Assess, Explain, and Lab & Info.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../heart_model.dart';
import '../l10n/strings.dart';
import 'assess_tab.dart';
import 'explain_tab.dart';
import 'heart_controller.dart';
import 'lab_info_tab.dart';
import 'theme.dart';

class InstrumentShell extends StatefulWidget {
  const InstrumentShell({
    super.key,
    this.model,
    this.initialTab = 0,
  });

  /// Injected directly in widget tests; null loads assets/model.json offline.
  final HeartModel? model;
  final int initialTab;

  @override
  State<InstrumentShell> createState() => _InstrumentShellState();
}

class _InstrumentShellState extends State<InstrumentShell> {
  late int _tabIndex = widget.initialTab.clamp(0, 2);
  late final HeartController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HeartController(initialModel: widget.model);
    if (widget.model == null) {
      _loadAssetModel();
    }
  }

  Future<void> _loadAssetModel() async {
    try {
      final raw = await rootBundle.loadString('assets/model.json');
      if (!mounted) return;
      _controller.setModel(HeartModel.fromJsonString(raw));
    } catch (e) {
      if (!mounted) return;
      _controller.setLoadError('$e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectTab(int idx) {
    if (_tabIndex == idx) return;
    HapticFeedback.selectionClick();
    setState(() => _tabIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final pal = BioVantaPalette.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (!_controller.isReady) {
          final err = _controller.loadError;
          return Scaffold(
            backgroundColor: pal.canvas,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  err != null
                      ? s.sf('errorModelLoad', {'error': err})
                      : s.s('errorModelLoading'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: pal.textPrimary),
                ),
              ),
            ),
          );
        }

        final model = _controller.model!;
        return Scaffold(
          backgroundColor: pal.canvas,
          extendBody: true,
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _tabIndex,
              children: [
                AssessTab(
                  controller: _controller,
                  bottomDockPadding: 112,
                ),
                ExplainTab(
                  controller: _controller,
                  bottomDockPadding: 112,
                ),
                LabInfoTab(
                  model: model,
                  bottomDockPadding: 112,
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: pal.dockBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: pal.borderAccent),
                    boxShadow: pal.isDark
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      _DockItem(
                        key: const ValueKey('nav_assess'),
                        label: s.s('navAssess'),
                        icon: Icons.favorite_outline,
                        activeIcon: Icons.favorite,
                        selected: _tabIndex == 0,
                        onTap: () => _selectTab(0),
                      ),
                      _DockItem(
                        key: const ValueKey('nav_explain'),
                        label: s.s('navExplain'),
                        icon: Icons.bar_chart_outlined,
                        activeIcon: Icons.bar_chart,
                        selected: _tabIndex == 1,
                        onTap: () => _selectTab(1),
                      ),
                      _DockItem(
                        key: const ValueKey('nav_lab'),
                        label: s.s('navLabInfo'),
                        icon: Icons.biotech_outlined,
                        activeIcon: Icons.biotech,
                        selected: _tabIndex == 2,
                        onTap: () => _selectTab(2),
                      ),
                    ],
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

class _DockItem extends StatelessWidget {
  const _DockItem({
    super.key,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = BioVantaPalette.of(context);
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? pal.cyan.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: selected
                ? Border.all(color: pal.cyan.withValues(alpha: 0.35))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? activeIcon : icon,
                size: 19,
                color: selected ? pal.cyan : pal.textMuted,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected ? pal.cyan : pal.textMuted,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
