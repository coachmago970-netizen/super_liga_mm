import "package:flutter/material.dart";

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    this.subtitle
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle ?? "Tela em construcao na fase atual.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280))
                )
              ]
            )
          )
        )
      )
    );
  }
}
