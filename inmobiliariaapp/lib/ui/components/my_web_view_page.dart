import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

// =========================================================================
// 1. CLASE CONTROLADORA (La que te faltaba definir o importar)
// =========================================================================
class CustomInAppWebController extends ChangeNotifier {
  InAppWebViewController? _webViewController;
  String _currentUrl = "";
  bool _isLoading = false;
  double _progress = 0.0;

  String get currentUrl => _currentUrl;
  bool get isLoading => _isLoading;
  double get progress => _progress;
  InAppWebViewController? get controller => _webViewController;

  void setController(InAppWebViewController controller) {
    _webViewController = controller;
  }

  Future<void> loadUrl(String url) async {
    if (_webViewController != null) {
      await _webViewController!.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );
    }
  }

  void updateUrl(WebUri? url) {
    if (url != null) {
      _currentUrl = url.toString();
      notifyListeners();
    }
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void updateProgress(int progress) {
    _progress = progress / 100;
    notifyListeners();
  }

  Future<void> goBack() async {
    if (await _webViewController?.canGoBack() ?? false) {
      await _webViewController?.goBack();
    }
  }

  Future<void> reload() async {
    await _webViewController?.reload();
  }
}

// =========================================================================
// 2. TU VISTA DE FLUTTER (Tu código corregido)
// =========================================================================
class MyWebViewPage extends StatefulWidget {
  final String initialUrl;

  const MyWebViewPage({Key? key, required this.initialUrl}) : super(key: key);

  @override
  State<MyWebViewPage> createState() => _MyWebViewPageState();
}

class _MyWebViewPageState extends State<MyWebViewPage> {
  late CustomInAppWebController _webController;

  @override
  void initState() {
    super.initState();
    _webController = CustomInAppWebController();
  }

  @override
  void dispose() {
    _webController.dispose(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Navegador InApp"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _webController.reload(),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _webController,
        builder: (context, child) {
          return Column(
            children: [
              if (_webController.isLoading)
                LinearProgressIndicator(value: _webController.progress),

              Container(
                padding: const EdgeInsets.all(8.0),
                color: Colors.grey[200],
                width: double.infinity,
                child: Text(
                  "URL Actual: ${_webController.currentUrl.isEmpty ? widget.initialUrl : _webController.currentUrl}",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              Expanded(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
                  initialSettings: InAppWebViewSettings(
                    useShouldOverrideUrlLoading: true, 
                    mediaPlaybackRequiresUserGesture: false,
                  ),
                  onWebViewCreated: (controller) {
                    _webController.setController(controller);
                  },
                  onLoadStart: (controller, url) {
                    _webController.setLoading(true);
                    _webController.updateUrl(url);
                  },
                  onLoadStop: (controller, url) {
                    _webController.setLoading(false);
                    _webController.updateUrl(url);
                  },
                  onProgressChanged: (controller, progress) {
                    _webController.updateProgress(progress);
                  },
                  shouldOverrideUrlLoading: (controller, navigationAction) async {
                    var uri = navigationAction.request.url;
                    
                    if (uri != null && uri.toString().contains("cancelar")) {
                      print("El usuario hizo clic en un link de cancelación: $uri");
                      Navigator.pop(context);
                      return NavigationActionPolicy.CANCEL; 
                    }
                    
                    return NavigationActionPolicy.ALLOW; 
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _webController,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _webController.goBack(),
              ),
            ],
          );
        },
      ),
    );
  }
}