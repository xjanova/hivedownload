import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/netwix_api.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// In-app viewer for the legal pages (ข้อตกลงการใช้งาน / นโยบายความเป็นส่วนตัว).
/// Renders the live web pages so the app always shows exactly what admin last
/// published — no duplicated copy to drift out of date.
class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key, required this.doc});

  /// 'terms' | 'privacy'
  final String doc;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  String get _url => widget.doc == 'privacy' ? NetwixApi.privacyUrl : NetwixApi.termsUrl;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled) // static legal text needs no JS
      ..setBackgroundColor(const Color(0xFF07050C))
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        // Keep the viewer on our own legal pages; ignore taps that leave them.
        onNavigationRequest: (req) {
          final uri = Uri.tryParse(req.url);
          return (uri != null && uri.host == Uri.parse(NetwixApi.origin).host)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse(_url));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<AppState>().l;
    final title = widget.doc == 'privacy'
        ? l.pick('นโยบายความเป็นส่วนตัว', 'Privacy Policy')
        : l.pick('ข้อตกลงการใช้งาน', 'Terms of Service');

    return Scaffold(
      backgroundColor: T.screen,
      appBar: AppBar(
        backgroundColor: T.screen,
        title: Text(title, style: AppTheme.display(17, weight: FontWeight.w700)),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: T.accent)),
        ],
      ),
    );
  }
}
