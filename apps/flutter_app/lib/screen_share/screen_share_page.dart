import "package:flutter/material.dart";

class ScreenSharePage extends StatelessWidget {
  const ScreenSharePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Compartilhamento de Tela")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Status do MVP",
                    style: TextStyle(fontWeight: FontWeight.w700)
                  ),
                  SizedBox(height: 8),
                  Text("Android: integrado ao botao da chamada com permissao de captura."),
                  Text("Desktop: integrado ao botao da chamada com seletor de janela/tela."),
                  Text("iOS: fase posterior (Broadcast Upload Extension + App Group).")
                ]
              )
            )
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Como validar no teste local",
                    style: TextStyle(fontWeight: FontWeight.w700)
                  ),
                  SizedBox(height: 8),
                  Text("1. Entre em Canal de Voz e toque em Compartilhar Tela."),
                  Text("2. Desktop: escolha uma janela/tela no seletor e confirme."),
                  Text("3. Android: aceite permissao de captura e valide o preview."),
                  Text("4. Em outra conta, confirme que a tela aparece na chamada.")
                ]
              )
            )
          )
        ]
      )
    );
  }
}
