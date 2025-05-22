import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  final String? message;
  final Color? color;
  final double size;

  const LoadingIndicator({
    super.key,
    this.message,
    this.color,
    this.size = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? Theme.of(context).primaryColor,
              ),
              strokeWidth: 4.0,
            ),
          ),
          if (message != null) ...[
            SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(fontSize: 16, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
