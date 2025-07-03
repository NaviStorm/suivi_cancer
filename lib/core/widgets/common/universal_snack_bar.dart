import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class UniversalSnackBar extends StatefulWidget {
  final String title;
  final String? message;
  final Duration duration;
  final Color? backgroundColor;
  final Color? titleColor;
  final Color? messageColor;
  final VoidCallback? onTap;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final bool isError; // Nouveau paramètre pour les erreurs

  const UniversalSnackBar({
    super.key,
    required this.title,
    this.message,
    this.duration = const Duration(seconds: 4), // Durée par défaut à 4 sec
    this.backgroundColor,
    this.titleColor,
    this.messageColor,
    this.onTap,
    this.actionLabel,
    this.onActionPressed,
    this.isError = false, // Par défaut, ce n'est pas une erreur
  });

  @override
  State<UniversalSnackBar> createState() => _UniversalSnackBarState();

  static void show(
      BuildContext context, {
        required String title,
        String? message,
        Duration duration = const Duration(seconds: 4), // Durée par défaut à 4 sec
        Color? backgroundColor,
        Color? titleColor,
        Color? messageColor,
        String? actionLabel,
        VoidCallback? onActionPressed,
        bool isError = false, // Nouveau paramètre pour les erreurs
      }) {
    if (_isApplePlatform()) {
      _showCupertinoSnackBar(
        context,
        title: title,
        message: message,
        duration: duration,
        backgroundColor: backgroundColor,
        titleColor: titleColor,
        messageColor: messageColor,
        actionLabel: actionLabel,
        onActionPressed: onActionPressed,
        isError: isError,
      );
    } else {
      _showMaterialSnackBar(
        context,
        title: title,
        message: message,
        duration: duration,
        backgroundColor: backgroundColor,
        titleColor: titleColor,
        messageColor: messageColor,
        actionLabel: actionLabel,
        onActionPressed: onActionPressed,
        isError: isError,
      );
    }
  }

  static bool _isApplePlatform() {
    if (kIsWeb) {
      return false;
    }
    return Platform.isIOS || Platform.isMacOS;
  }

  static void _showCupertinoSnackBar(
      BuildContext context, {
        required String title,
        String? message,
        Duration duration = const Duration(seconds: 4),
        Color? backgroundColor,
        Color? titleColor,
        Color? messageColor,
        String? actionLabel,
        VoidCallback? onActionPressed,
        bool isError = false,
      }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).padding.bottom + 20,
        left: 16,
        right: 16,
        child: UniversalSnackBar(
          title: title,
          message: message,
          duration: duration, // Durée correctement transmise
          backgroundColor: backgroundColor,
          titleColor: titleColor,
          messageColor: messageColor,
          actionLabel: actionLabel,
          onActionPressed: onActionPressed,
          isError: isError,
          onTap: () => overlayEntry.remove(),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(duration, () { // Utilise la durée passée en paramètre
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  static void _showMaterialSnackBar(
      BuildContext context, {
        required String title,
        String? message,
        Duration duration = const Duration(seconds: 4),
        Color? backgroundColor,
        Color? titleColor,
        Color? messageColor,
        String? actionLabel,
        VoidCallback? onActionPressed,
        bool isError = false,
      }) {
    // Couleurs par défaut pour Material
    final defaultBackgroundColor = isError
        ? Colors.red
        : Colors.black;

    final defaultTitleColor = isError
        ? Colors.black
        : Colors.white;

    final defaultMessageColor = isError
        ? Colors.black.withValues(alpha: 0.8)
        : Colors.white.withValues(alpha: 0.9);

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            color: titleColor ?? defaultTitleColor,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(
              color: messageColor ?? defaultMessageColor,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: content,
        duration: duration, // Durée correctement transmise
        backgroundColor: backgroundColor ?? defaultBackgroundColor,
        action: actionLabel != null && onActionPressed != null
            ? SnackBarAction(
          label: actionLabel,
          onPressed: onActionPressed,
        )
            : null,
      ),
    );
  }
}

class _UniversalSnackBarState extends State<UniversalSnackBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();

    // Utilise widget.duration au lieu d'une valeur codée en dur
    Future.delayed(widget.duration - const Duration(milliseconds: 300), () {
      if (mounted) {
        _animationController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Couleurs par défaut améliorées
    final defaultBackgroundColor = widget.isError
        ? CupertinoColors.systemRed
        : CupertinoColors.black;

    final defaultTitleColor = widget.isError
        ? CupertinoColors.black
        : CupertinoColors.white;

    final defaultMessageColor = widget.isError
        ? CupertinoColors.black.withValues(alpha: 0.8)
        : CupertinoColors.white.withValues(alpha: 0.9);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: widget.backgroundColor ?? defaultBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              color: widget.titleColor ?? defaultTitleColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.message != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.message!,
                              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                                color: widget.messageColor ?? defaultMessageColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.actionLabel != null && widget.onActionPressed != null)
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        onPressed: widget.onActionPressed,
                        child: Text(
                          widget.actionLabel!,
                          style: TextStyle(
                            color: widget.isError
                                ? CupertinoColors.black
                                : CupertinoColors.activeBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
