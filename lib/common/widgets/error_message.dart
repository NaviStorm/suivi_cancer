import 'package:flutter/material.dart';

class ErrorMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorMessage({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red[700], size: 48),
            SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: Icon(Icons.refresh),
                label: Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
