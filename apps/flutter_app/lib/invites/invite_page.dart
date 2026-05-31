import "dart:async";
import "dart:convert";
import "package:app_links/app_links.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:http/http.dart" as http;
import "../auth/auth_providers.dart";
import "../core/env.dart";

class InviteEntryPage extends ConsumerStatefulWidget {
  const InviteEntryPage({
    super.key,
    this.initialCode
  });

  final String? initialCode;

  @override
  ConsumerState<InviteEntryPage> createState() => _InviteEntryPageState();
}

class _InviteEntryPageState extends ConsumerState<InviteEntryPage> {
  final _appLinks = AppLinks();
  final _codeController = TextEditingController();
  StreamSubscription<Uri>? _linkSubscription;
  bool _loadingValidate = false;
  bool _loadingUse = false;
  String? _statusText;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _setupDeepLinks();
    final code = widget.initialCode?.trim().toUpperCase();
    if (code != null && code.isNotEmpty) {
      _codeController.text = code;
      WidgetsBinding.instance.addPostFrameCallback((_) => _validateInvite());
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _setupDeepLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _tryApplyInviteCodeFromUri(initial);
      }
    } catch (error) {
      debugPrint("Initial invite link error: $error");
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _tryApplyInviteCodeFromUri(uri);
    }, onError: (Object error) {
      debugPrint("Invite uri stream error: $error");
    });
  }

  void _tryApplyInviteCodeFromUri(Uri uri) {
    final extracted = _extractCode(uri);
    if (extracted == null || extracted.isEmpty) return;
    _codeController.text = extracted;
    _validateInvite();
  }

  String? _extractCode(Uri uri) {
    final queryCode = uri.queryParameters["code"]?.trim().toUpperCase();
    if (queryCode != null && queryCode.isNotEmpty) {
      return queryCode;
    }

    final segments = uri.pathSegments.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (segments.length >= 2 && segments.first.toLowerCase() == "invite") {
      return segments[1].toUpperCase();
    }

    if (uri.host.toLowerCase() == "invite" && segments.isNotEmpty) {
      return segments.first.toUpperCase();
    }

    return null;
  }

  Uri _buildUrl(String path) {
    final base = AppEnv.backendBaseUrl;
    if (base.isEmpty) {
      throw Exception("BACKEND_BASE_URL nao configurado no app.");
    }
    return Uri.parse("$base$path");
  }

  String get _inviteCode => _codeController.text.trim().toUpperCase();

  Future<void> _validateInvite() async {
    if (_inviteCode.isEmpty) return;
    setState(() {
      _loadingValidate = true;
      _statusText = null;
      _isValid = false;
    });

    try {
      final response = await http.post(
        _buildUrl("/invites/validate"),
        headers: {"content-type": "application/json"},
        body: jsonEncode({"code": _inviteCode})
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final valid = body["valid"] == true;
      setState(() {
        _isValid = valid;
        _statusText = valid ? "Convite valido." : _reasonText(body["reason"]?.toString());
      });
    } catch (error) {
      setState(() => _statusText = "Nao foi possivel validar agora.");
      debugPrint("Invite validate error: $error");
    } finally {
      if (mounted) {
        setState(() => _loadingValidate = false);
      }
    }
  }

  Future<void> _useInvite() async {
    if (!_isValid || _inviteCode.isEmpty) return;
    final session = ref.read(currentSessionProvider);
    if (session == null) {
      if (!mounted) return;
      context.go("/login");
      return;
    }

    setState(() {
      _loadingUse = true;
      _statusText = null;
    });

    try {
      final response = await http.post(
        _buildUrl("/invites/use"),
        headers: {
          "content-type": "application/json",
          "authorization": "Bearer ${session.accessToken}"
        },
        body: jsonEncode({"code": _inviteCode})
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300 && body["ok"] == true) {
        if (!mounted) return;
        setState(() => _statusText = "Convite aplicado. Voce entrou no servidor.");
        context.go("/server");
        return;
      }

      setState(() => _statusText = body["error"]?.toString() ?? "Nao foi possivel usar convite.");
    } catch (error) {
      setState(() => _statusText = "Falha ao usar convite.");
      debugPrint("Invite use error: $error");
    } finally {
      if (mounted) {
        setState(() => _loadingUse = false);
      }
    }
  }

  String _reasonText(String? reason) {
    switch (reason) {
      case "inactive":
        return "Convite desativado.";
      case "expired":
        return "Convite expirado.";
      case "max_uses_reached":
        return "Convite atingiu o limite de uso.";
      case "rate_limited":
        return "Muitas tentativas. Tente novamente em instantes.";
      default:
        return "Convite invalido.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Entrada por Convite")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Cole seu codigo de convite para entrar no servidor.",
                    style: TextStyle(color: Color(0xFF6B7280))
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: "Codigo do convite",
                      hintText: "ABC123"
                    )
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _loadingValidate ? null : _validateInvite,
                    child: Text(_loadingValidate ? "Validando..." : "Validar convite")
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _loadingUse ? null : _useInvite,
                    child: Text(_loadingUse ? "Entrando..." : "Usar convite")
                  ),
                  if (_statusText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _statusText!,
                      style: TextStyle(
                        color: _isValid ? const Color(0xFF16A34A) : const Color(0xFFDC2626)
                      )
                    )
                  ]
                ]
              )
            )
          )
        )
      )
    );
  }
}
