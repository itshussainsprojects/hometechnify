import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/constants/constants.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final Map<String, dynamic> paymentData;
  final String paymentMethod; // 'JAZZCASH' or 'EASYPAISA'
  
  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.paymentData,
    required this.paymentMethod,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('📄 Page started loading: $url');
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            debugPrint('✅ Page finished loading: $url');
            setState(() => _isLoading = false);
            
            // Check if callback URL
            if (url.contains('/booking-success') || url.contains('/booking-failed')) {
              _handleCallback(url);
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('🚨 WebView error: ${error.description}');
          },
        ),
      );

    // For POST request, we need to inject form and submit
    _loadPaymentForm();
  }

  void _loadPaymentForm() {
    // Generate HTML form with payment data
    final formFields = widget.paymentData.entries
        .map((entry) => '<input type="hidden" name="${entry.key}" value="${entry.value}">')
        .join('\n');

    final html = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            font-family: Arial, sans-serif;
          }
          .loader {
            text-align: center;
            color: white;
          }
          .spinner {
            border: 4px solid #f3f3f3;
            border-top: 4px solid #667eea;
            border-radius: 50%;
            width: 50px;
            height: 50px;
            animation: spin 1s linear infinite;
            margin: 0 auto 20px;
          }
          @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
          }
        </style>
      </head>
      <body>
        <div class="loader">
          <div class="spinner"></div>
          <h2>Processing Payment...</h2>
          <p>Please wait while we redirect you to ${widget.paymentMethod}</p>
        </div>
        <form id="paymentForm" method="POST" action="${widget.paymentUrl}">
          $formFields
        </form>
        <script>
          document.getElementById('paymentForm').submit();
        </script>
      </body>
      </html>
    ''';

    _controller.loadHtmlString(html);
  }

  void _handleCallback(String url) {
    // Parse URL to check success/failure
    final uri = Uri.parse(url);
    
    if (url.contains('/booking-success')) {
      final bookingId = uri.queryParameters['bookingId'];
      
      // Navigate back with success
      Navigator.pop(context, {
        'success': true,
        'bookingId': bookingId,
        'message': 'Payment successful!',
      });
    } else if (url.contains('/booking-failed')) {
      final message = uri.queryParameters['message'] ?? 'Payment failed';
      
      // Navigate back with failure
      Navigator.pop(context, {
        'success': false,
        'message': message,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () {
            // Show confirmation dialog
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Cancel Payment?'),
                content: const Text('Are you sure you want to cancel this payment?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('No'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context, {
                        'success': false,
                        'message': 'Payment cancelled by user',
                      }); // Close payment screen
                    },
                    child: const Text('Yes', style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            );
          },
        ),
        title: Text(
          '${widget.paymentMethod} Payment',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          
          // Loading indicator
          if (_isLoading)
            Container(
              color: AppColors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading payment gateway...',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
