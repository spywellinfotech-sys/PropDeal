import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFFC9420A),
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const PropertyNetworkApp());
}

class PropertyNetworkApp extends StatelessWidget {
  const PropertyNetworkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PropDeal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFF26A0F),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.parse(request.url);
            // Page ke andar wale links (asset file) WebView me hi khulein.
            if (uri.scheme == 'file' ||
                uri.scheme == 'about' ||
                uri.scheme == 'data' ||
                uri.host.contains('fonts.googleapis.com') ||
                uri.host.contains('fonts.gstatic.com')) {
              return NavigationDecision.navigate;
            }
            // Call (tel:), WhatsApp (wa.me) aur baaki links phone ke apps me khulein.
            _openExternal(uri);
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadFlutterAsset('assets/index.html');
  }

  Future<void> _openExternal(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ye link nahi khul paaya. Number copy karke try karein.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8F2),
        body: SafeArea(child: WebViewWidget(controller: _controller)),
      ),
    );
  }
}
