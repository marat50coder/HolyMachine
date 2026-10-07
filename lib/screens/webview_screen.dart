import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0a0604))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p),
          onPageFinished: (_) => setState(() => _progress = 100),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0604),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a0e07),
        foregroundColor: const Color(0xFFFFD17A),
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: Column(
        children: [
          if (_progress < 100)
            LinearProgressIndicator(
              value: _progress / 100,
              backgroundColor: Colors.black26,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFFF8A1A)),
            ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
