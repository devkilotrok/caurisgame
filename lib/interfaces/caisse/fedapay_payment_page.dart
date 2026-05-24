import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Page de paiement FedaPay intégrée dans l'application
/// Affiche la page de paiement FedaPay dans une WebView au lieu de rediriger vers un navigateur externe
class FedaPayPaymentPage extends StatefulWidget {
  final String paymentUrl;
  final String transactionId;
  final int amountFcfa;
  final int cauris;
  
  const FedaPayPaymentPage({
    super.key,
    required this.paymentUrl,
    required this.transactionId,
    required this.amountFcfa,
    required this.cauris,
  });

  @override
  State<FedaPayPaymentPage> createState() => _FedaPayPaymentPageState();
}

class _FedaPayPaymentPageState extends State<FedaPayPaymentPage> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _errorMessage;
  bool _paymentCompleted = false;
  bool _paymentFailed = false;
  bool _isLinux = false;
  
  // ✅ Timer de 3 minutes pour l'expiration du paiement
  Timer? _paymentTimeoutTimer;
  int _remainingSeconds = 180; // 3 minutes = 180 secondes
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    // Détecter si on est sur une plateforme desktop (Linux/Windows/macOS) ou web
    // Sur mobile (Android/iOS), on utilise toujours la WebView
    if (kIsWeb) {
      _isLinux = true; // Web est traité comme desktop
    } else {
      _isLinux = Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    }
    
    // ✅ Démarrer le timer de 3 minutes
    _startPaymentTimeout();
    
    // Sur mobile (Android/iOS), toujours utiliser WebView
    // Sur desktop/web, ouvrir dans le navigateur externe
    if (!_isLinux) {
      _initializeWebView();
    } else {
      // Sur desktop/web, ouvrir directement dans le navigateur
      _openInBrowser();
    }
  }
  
  /// ✅ Démarrer le timer de 3 minutes pour l'expiration du paiement
  void _startPaymentTimeout() {
    _remainingSeconds = 180; // 3 minutes
    
    _paymentTimeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_paymentCompleted || _paymentFailed || _isExpired) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _remainingSeconds--;
      });
      
      // ✅ Si le temps est écoulé, expirer la transaction
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _handlePaymentExpiration();
      }
    });
  }
  
  /// ✅ Gérer l'expiration du paiement (3 minutes écoulées)
  void _handlePaymentExpiration() {
    if (_paymentCompleted || _paymentFailed || _isExpired) return;
    
    setState(() {
      _isExpired = true;
      _isLoading = false;
    });
    
    // Annuler le timer
    _paymentTimeoutTimer?.cancel();
    
    // Afficher un message d'expiration
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pop(false); // Retourner false = paiement expiré
      }
    });
  }
  
  @override
  void dispose() {
    _paymentTimeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _openInBrowser() async {
    try {
      final uri = Uri.parse(widget.paymentUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        // Mettre à jour l'état pour afficher le message
        setState(() {
          _isLoading = false;
        });
        // Sur Linux, on ne peut pas détecter le résultat, donc on ferme après un délai
        // L'utilisateur peut aussi cliquer sur le bouton
      } else {
        setState(() {
          _errorMessage = 'Impossible d\'ouvrir la page de paiement';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  void _initializeWebView() {
    if (_isLinux) return; // Ne pas initialiser sur desktop
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..enableZoom(true)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36'
      )
      ..addJavaScriptChannel(
        'PaymentStatus',
        onMessageReceived: (JavaScriptMessage message) {
          // Écouter les messages JavaScript de FedaPay
          final data = message.message.toLowerCase();
          if (data.contains('success') || data.contains('approved') || data.contains('transferred')) {
            _handlePaymentSuccess();
          } else if (data.contains('cancel') || data.contains('declined') || data.contains('failed')) {
            _handlePaymentFailure();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
              _checkPaymentStatus(url);
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              _checkPaymentStatus(url);
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = 'Erreur de chargement: ${error.description}';
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // Toujours permettre la navigation dans la WebView
            // Ne pas bloquer les redirections FedaPay
            final url = request.url.toLowerCase();
            
            // Vérifier si c'est une URL de succès/échec (mais ne pas bloquer)
            if (url.contains('success') || url.contains('approved') || url.contains('transferred')) {
              // Laisser la navigation se faire, puis vérifier après
              Future.delayed(const Duration(milliseconds: 500), () {
                _checkPaymentStatus(request.url);
              });
            } else if (url.contains('cancel') || url.contains('declined') || url.contains('failed')) {
              // Laisser la navigation se faire, puis vérifier après
              Future.delayed(const Duration(milliseconds: 500), () {
                _checkPaymentStatus(request.url);
              });
            }
            
            // Toujours permettre la navigation
            return NavigationDecision.navigate;
          },
          onUrlChange: (UrlChange change) {
            // Écouter les changements d'URL pour détecter le statut du paiement
            if (change.url != null) {
              _checkPaymentStatus(change.url!);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _checkPaymentStatus(String url) {
    // Vérifier les patterns d'URL qui indiquent un paiement réussi ou échoué
    final urlLower = url.toLowerCase();
    
    if (urlLower.contains('success') || 
        urlLower.contains('approved') || 
        urlLower.contains('transferred') ||
        urlLower.contains('payment-success')) {
      _handlePaymentSuccess();
    } else if (urlLower.contains('cancel') || 
               urlLower.contains('declined') || 
               urlLower.contains('failed') ||
               urlLower.contains('payment-failed')) {
      _handlePaymentFailure();
    }
  }

  void _handlePaymentSuccess() {
    if (_paymentCompleted) return; // Éviter les appels multiples
    
    // ✅ Annuler le timer car le paiement est réussi
    _paymentTimeoutTimer?.cancel();
    
    setState(() {
      _paymentCompleted = true;
      _isLoading = false;
    });

    // Attendre un peu pour que l'utilisateur voie le message de succès
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop(true); // Retourner true = paiement réussi
      }
    });
  }

  void _handlePaymentFailure() {
    if (_paymentFailed) return; // Éviter les appels multiples
    
    // ✅ Annuler le timer car le paiement a échoué
    _paymentTimeoutTimer?.cancel();
    
    setState(() {
      _paymentFailed = true;
      _isLoading = false;
    });

    // Attendre un peu avant de fermer
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop(false); // Retourner false = paiement échoué
      }
    });
  }
  
  /// ✅ Formater le temps restant en MM:SS
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () {
            // Demander confirmation avant de fermer
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Annuler le paiement ?'),
                content: const Text(
                  'Êtes-vous sûr de vouloir annuler ce paiement ? '
                  'Vous pourrez le compléter plus tard.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Continuer le paiement'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Fermer la dialog
                      Navigator.pop(context, false); // Fermer la page de paiement
                    },
                    child: const Text('Annuler', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
        ),
        title: Row(
          children: [
            const Icon(Icons.payment, color: Color(0xFF228B22)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paiement FedaPay',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // ✅ Afficher le temps restant
                  if (!_paymentCompleted && !_paymentFailed && !_isExpired)
                    Text(
                      'Temps restant: ${_formatTime(_remainingSeconds)}',
                      style: TextStyle(
                        color: _remainingSeconds <= 30 
                            ? Colors.red 
                            : (isDark ? Colors.white70 : Colors.black54),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // ✅ Bannière d'avertissement pour le temps limité
          if (!_paymentCompleted && !_paymentFailed && !_isExpired)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _remainingSeconds <= 30 
                      ? Colors.red.withOpacity(0.9)
                      : Colors.orange.withOpacity(0.9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _remainingSeconds <= 30
                          ? '⚠️ Dépôt expire dans ${_formatTime(_remainingSeconds)} !'
                          : '⏱️ Vous avez ${_formatTime(_remainingSeconds)} pour valider votre paiement',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // WebView (seulement si pas Linux)
          if (!_isLinux && _controller != null)
            Padding(
              padding: EdgeInsets.only(
                top: (!_paymentCompleted && !_paymentFailed && !_isExpired) ? 50 : 0,
              ),
              child: WebViewWidget(controller: _controller!),
            )
          else if (_isLinux)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.payment,
                      size: 64,
                      color: Color(0xFF228B22),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Paiement FedaPay',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Le paiement a été ouvert dans votre navigateur.\n'
                      'Veuillez compléter le paiement et revenir à l\'application.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(null);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF228B22),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: const Text('J\'ai terminé le paiement'),
                    ),
                  ],
                ),
              ),
            ),
          
          // Indicateur de chargement
          if (_isLoading && !_paymentCompleted && !_paymentFailed && !_isExpired)
            Container(
              color: isDark ? Colors.black : Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF228B22)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chargement de la page de paiement...',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ✅ Afficher le temps restant même pendant le chargement
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _remainingSeconds <= 30 
                            ? Colors.red.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _remainingSeconds <= 30 
                              ? Colors.red
                              : Colors.orange,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer,
                            color: _remainingSeconds <= 30 
                                ? Colors.red
                                : Colors.orange,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Temps restant: ${_formatTime(_remainingSeconds)}',
                            style: TextStyle(
                              color: _remainingSeconds <= 30 
                                  ? Colors.red
                                  : Colors.orange,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Message de succès
          if (_paymentCompleted)
            Container(
              color: Colors.green.withOpacity(0.95),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Paiement réussi !',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.cauris} Cauris ajoutés à votre compte',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Message d'échec
          if (_paymentFailed)
            Container(
              color: Colors.red.withOpacity(0.95),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Paiement échoué',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Veuillez réessayer ou contacter le support',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // ✅ Message d'expiration (3 minutes écoulées)
          if (_isExpired)
            Container(
              color: Colors.red.withOpacity(0.95),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.timer_off,
                      color: Colors.white,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Paiement expiré',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Le délai de 3 minutes est écoulé.\n'
                      'Votre transaction a été annulée.\n'
                      'Vous pouvez réessayer un nouveau dépôt.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Message d'erreur
          if (_errorMessage != null)
            Container(
              color: Colors.orange.withOpacity(0.95),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Erreur de chargement',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                            _isLoading = true;
                          });
                          _controller?.reload();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.orange,
                        ),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

