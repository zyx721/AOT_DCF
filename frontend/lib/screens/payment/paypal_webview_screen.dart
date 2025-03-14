import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PayPalWebViewScreen extends StatefulWidget {
  final String initialUrl;
  final Function(bool success) onPaymentComplete;

  const PayPalWebViewScreen({
    Key? key,
    required this.initialUrl,
    required this.onPaymentComplete,
  }) : super(key: key);

  @override
  _PayPalWebViewScreenState createState() => _PayPalWebViewScreenState();
}

class _PayPalWebViewScreenState extends State<PayPalWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (String url) {
          setState(() => _isLoading = true);
          if (url.contains('success')) {
            widget.onPaymentComplete(true);
            Navigator.of(context).pop();
          } else if (url.contains('cancel')) {
            widget.onPaymentComplete(false);
            Navigator.of(context).pop();
          }
        },
        onPageFinished: (String url) {
          setState(() => _isLoading = false);
        },
      ))
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PayPal Payment'),
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () {
            widget.onPaymentComplete(false);
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
