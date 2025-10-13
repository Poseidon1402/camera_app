import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  final String? errorMessage;
  final VoidCallback? onRetry;

  const LoadingScreen({
    super.key,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            errorMessage ?? 'Initializing face detection...',
            style: TextStyle(
              fontSize: 16,
              color: errorMessage != null ? Colors.red : Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          if (errorMessage != null && onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}
