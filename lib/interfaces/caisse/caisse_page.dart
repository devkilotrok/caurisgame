import 'package:flutter/material.dart';
import '../../services/api/payment_api_service.dart';
import 'fedapay_payment_page.dart';

// Classe pour représenter une transaction
class Transaction {
  final String id;
  final String type; // 'depot' ou 'retrait'
  final int montant;
  final int cauris;
  final DateTime date;
  final String status; // 'en_attente', 'valide', 'rejete'
  final String? imagePath;
  final String? beneficiaireName; // Nom du bénéficiaire pour les retraits

  Transaction({
    required this.id,
    required this.type,
    required this.montant,
    required this.cauris,
    required this.date,
    required this.status,
    this.imagePath,
    this.beneficiaireName,
  });
}

class CaissePage extends StatefulWidget {
  final int caurisBalance;
  
  const CaissePage({
    super.key,
    this.caurisBalance = 1000,
  });

  @override
  State<CaissePage> createState() => _CaissePageState();
}

class _CaissePageState extends State<CaissePage> {
  final TextEditingController _montantFcfaController = TextEditingController();
  final TextEditingController _nombreCaurisController = TextEditingController();
  final TextEditingController _numeroTelephoneController = TextEditingController();
  final TextEditingController _beneficiaireNameController = TextEditingController();
  final TextEditingController _depotPhoneController = TextEditingController(); // Pour les dépôts FedaPay
  final TextEditingController _depotCaurisController = TextEditingController(); // Nombre de cauris à acheter
  int _currentBalance = 0; // Solde dynamique
  int _calculatedFcfaAmount = 0; // Montant FCFA calculé
  List<Transaction> _transactions = []; // Historique dynamique
  String _filter = 'all'; // all | depot | retrait

  @override
  void initState() {
    super.initState();
    _currentBalance = widget.caurisBalance;
    _loadTransactionsFromBackend();
    _loadBalanceFromBackend();
  }

  /// Charger le solde actuel depuis le backend
  Future<void> _loadBalanceFromBackend() async {
    try {
      final res = await PaymentApiService.instance.getBalance();
      if (res['success'] == true) {
        setState(() {
          _currentBalance = res['balance'] as int? ?? widget.caurisBalance;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement du solde: $e');
    }
  }

  Future<void> _loadTransactionsFromBackend() async {
    try {
      final res = await PaymentApiService.instance.getTransactions();
      if (res['success'] == true) {
        final List data = res['data'] as List;
        setState(() {
          // Vider d'abord les transactions existantes pour éviter les doublons
          _transactions.clear();
          // Charger uniquement les transactions depuis le backend
          _transactions = data.map((t) {
            return Transaction(
              id: (t['transaction_id'] ?? t['id'] ?? '').toString(),
              type: (t['type'] ?? '').toString(),
              montant: (t['fcfa_amount'] ?? 0) as int,
              cauris: (t['cauris_amount'] ?? 0) as int,
              date: DateTime.tryParse((t['created_at'] ?? '').toString()) ?? DateTime.now(),
              status: (t['status'] ?? 'en_attente').toString(),
              imagePath: (t['image_path'] ?? '') as String?,
              beneficiaireName: (t['beneficiaire_name'] ?? '') as String?,
            );
          }).toList();
        });
      } else {
        // Si erreur, s'assurer que la liste est vide
        setState(() {
          _transactions.clear();
        });
      }
    } catch (e) {
      // En cas d'erreur, vider la liste pour éviter d'afficher de fausses données
      setState(() {
        _transactions.clear();
      });
      print('Erreur lors du chargement des transactions: $e');
    }
  }

  @override
  void dispose() {
    _montantFcfaController.dispose();
    _nombreCaurisController.dispose();
    _numeroTelephoneController.dispose();
    _beneficiaireNameController.dispose();
    _depotPhoneController.dispose();
    _depotCaurisController.dispose();
    super.dispose();
  }

  // Calculer le montant FCFA à partir du nombre de cauris
  void _calculateFcfaAmount() {
    final caurisText = _depotCaurisController.text.trim();
    if (caurisText.isEmpty) {
      setState(() {
        _calculatedFcfaAmount = 0;
      });
      return;
    }
    
    final cauris = int.tryParse(caurisText);
    if (cauris != null && cauris > 0) {
      // 10 cauris = 1000 FCFA, donc 1 cauris = 100 FCFA
      setState(() {
        _calculatedFcfaAmount = cauris * 100;
      });
    } else {
      setState(() {
        _calculatedFcfaAmount = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Caisse Virtuelle',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // Logo circulaire avec icône de caisse
            _buildLogo(),
            
            const SizedBox(height: 32),
            
            // Section Solde actuel
            _buildSoldeSection(),
            
            const SizedBox(height: 24),
            
            // Section Acheter des Cauris (Dépôt)
            _buildAcheterSection(),
            
            const SizedBox(height: 24),
            
            // Section Retirer des Cauris
            _buildRetirerSection(),
            
            const SizedBox(height: 24),
            
            // Section Historique des Transactions
          _buildHistoriqueSection(),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF404040),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logocauris.jpeg',
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildSoldeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Solde actuel',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_currentBalance cauris',
            style: const TextStyle(
              color: Color(0xFFFFD700), // Jaune vif
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcheterSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acheter des Cauris',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          const Text(
            '10 cauris = 1 000 FCFA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Champ Nombre de cauris
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nombre de cauris',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _depotCaurisController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => _calculateFcfaAmount(),
                decoration: InputDecoration(
                  hintText: 'Ex: 100',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              // Afficher le montant calculé
              if (_calculatedFcfaAmount > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF228B22).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF228B22),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calculate,
                        color: Color(0xFF228B22),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Montant à payer: ${_calculatedFcfaAmount.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                          color: Color(0xFF228B22),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Champ Numéro de téléphone pour FedaPay
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Votre numéro de téléphone',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _depotPhoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ex: +229 01 23 45 67 89',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  prefixIcon: const Icon(
                    Icons.phone,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF3B82F6),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF3B82F6),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Le paiement sera effectué via FedaPay directement dans l\'application.\n'
                        '⚠️ IMPORTANT: Vous avez 3 minutes pour valider votre paiement. '
                        'Passé ce délai, la transaction sera automatiquement annulée.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Bouton Déposer
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                _handleDepot();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF228B22), // Vert plus foncé
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Déposer',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetirerSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Retirer des Cauris',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Champ Nombre de cauris
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nombre de cauris',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nombreCaurisController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ex: 50',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Champ Nom du bénéficiaire
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nom du bénéficiaire',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _beneficiaireNameController,
                keyboardType: TextInputType.text,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ex: John DOE',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Champ Numéro de téléphone
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Numéro de téléphone',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _numeroTelephoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ex: +229 01 23 45 67 89',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Bouton Retirer
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                _handleRetrait();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, // Orange vif
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Retirer',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoriqueSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bar_chart,
                color: Colors.red,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Historique des Transactions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ChoiceChip(
                label: const Text('Tous'),
                selected: _filter == 'all',
                onSelected: (_) => setState(() => _filter = 'all'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Dépôts'),
                selected: _filter == 'depot',
                onSelected: (_) => setState(() => _filter = 'depot'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Retraits'),
                selected: _filter == 'retrait',
                onSelected: (_) => setState(() => _filter = 'retrait'),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Affichage des transactions
          if (_transactions.isEmpty)
            const Center(
              child: Text(
                'Aucune transaction',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            )
          else
            Column(
              children: _transactions
                  .where((t) => _filter == 'all' ? true : t.type == _filter)
                  .map((transaction) => _buildTransactionItem(transaction))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _handleDepot() async {
    final nombreCauris = _depotCaurisController.text.trim();
    final phoneNumber = _depotPhoneController.text.trim();
    
    if (nombreCauris.isEmpty) {
      _showErrorDialog('Erreur', 'Veuillez saisir le nombre de cauris');
      return;
    }
    
    final caurisInt = int.tryParse(nombreCauris);
    if (caurisInt == null || caurisInt <= 0) {
      _showErrorDialog('Erreur', 'Nombre de cauris invalide');
      return;
    }
    
    if (caurisInt < 10) {
      _showErrorDialog('Erreur', 'Le minimum est de 10 cauris');
      return;
    }
    
    if (phoneNumber.isEmpty) {
      _showErrorDialog('Erreur', 'Veuillez saisir votre numéro de téléphone');
      return;
    }
    
    // Calculer le montant en FCFA (10 cauris = 1000 FCFA, donc 1 cauris = 100 FCFA)
    final montantFcfa = caurisInt * 100;
    
    // Afficher un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
        ),
      ),
    );
    
    try {
      // Appel API backend pour initier le paiement FedaPay
      final res = await PaymentApiService.instance.deposit(
        amountFcfa: montantFcfa,
        phoneNumber: phoneNumber,
      );
      
      // Fermer l'indicateur de chargement
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (res['success'] != true) {
        // ✅ Améliorer l'affichage des erreurs avec plus de détails
        final errorMessage = res['message'] as String? ?? 'Erreur lors de l\'initiation du paiement';
        final statusCode = res['status_code'] as int?;
        final errorData = res['error_data'] as Map<String, dynamic>?;
        final isConnectivityError = res['connectivity_error'] == true;
        final errorType = res['error_type'] as String?;
        
        // Construire un message d'erreur détaillé
        String detailedMessage = errorMessage;
        
        if (statusCode != null) {
          detailedMessage += '\n\nCode d\'erreur: $statusCode';
        }
        
        // ✅ Détecter les erreurs de connexion
        final errorLower = errorMessage.toLowerCase();
        if (statusCode == 502 ||
            statusCode == 503 ||
            isConnectivityError ||
            errorType == 'connection' ||
            errorLower.contains('impossible de se connecter') ||
            errorLower.contains('connection') ||
            errorLower.contains('socket')) {
          detailedMessage += '\n\n🔧 Solutions pour résoudre le problème:';
          detailedMessage += '\n\n1️⃣ Vérifier que Laravel est démarré:';
          detailedMessage += '\n   • Ouvrez un terminal et exécutez:';
          detailedMessage += '\n     cd /opt/lampp/htdocs/backendCauris';
          detailedMessage += '\n     php artisan serve';
          detailedMessage += '\n\n2️⃣ Vérifier que l\'URL est correcte:';
          detailedMessage += '\n   • L\'URL doit pointer vers votre serveur local';
          detailedMessage += '\n   • Exemple: http://192.168.1.87:8000/api';
          detailedMessage += '\n   • Vérifiez dans lib/config/api_config.dart';
          detailedMessage += '\n\n3️⃣ Vérifier la connectivité:';
          detailedMessage += '\n   • Testez avec: curl http://192.168.1.87:8000/api/payment/balance';
          detailedMessage += '\n   • Si vous testez sur téléphone, assurez-vous qu\'il est sur le même WiFi';
          detailedMessage += '\n\n4️⃣ Vérifier les logs Laravel:';
          detailedMessage += '\n   • tail -f /opt/lampp/htdocs/backendCauris/storage/logs/laravel.log';
        } else if (errorLower.contains('timeout')) {
          detailedMessage += '\n\n💡 Solutions possibles:';
          detailedMessage += '\n• Vérifiez votre connexion internet';
          detailedMessage += '\n• Vérifiez que le serveur est accessible';
          detailedMessage += '\n• Vérifiez que Laravel répond: curl http://192.168.1.87:8000/api/payment/balance';
          detailedMessage += '\n• Réessayez dans quelques instants';
        }
        
        _showErrorDialog('Erreur de paiement', detailedMessage);
        return;
      }
      
      // Récupérer l'URL de paiement et les informations de transaction
      final paymentUrl = res['payment_url'] as String?;
      final transactionIdValue = res['transaction_id'];
      // Le transaction_id peut être un int ou un String selon le backend
      final String? transactionId = transactionIdValue != null 
          ? transactionIdValue.toString() 
          : null;
      final data = res['data'] as Map<String, dynamic>?;
      final caurisAmount = data?['cauris'] as int? ?? caurisInt;
      
      if (paymentUrl != null && paymentUrl.isNotEmpty && transactionId != null) {
        // Ouvrir la page de paiement intégrée dans l'application
        final paymentResult = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => FedaPayPaymentPage(
              paymentUrl: paymentUrl,
              transactionId: transactionId,
              amountFcfa: montantFcfa,
              cauris: caurisAmount,
            ),
          ),
        );
        
        // ✅ Recharger l'historique et le solde après le paiement
        // Le backend devrait avoir automatiquement crédité le compte via webhook/callback
        await Future.wait([
          _loadTransactionsFromBackend(),
          _loadBalanceFromBackend(),
        ]);
        
        setState(() {
          _depotCaurisController.clear();
          _depotPhoneController.clear();
          _calculatedFcfaAmount = 0;
        });
        
        // Afficher un message selon le résultat
        if (paymentResult == true) {
          // ✅ Vérifier que le solde a bien été mis à jour
          final updatedBalance = await PaymentApiService.instance.getBalance();
          final newBalance = updatedBalance['balance'] as int? ?? _currentBalance;
          
          _showSuccessDialog(
            'Paiement réussi !',
            'Votre compte a été crédité de $caurisAmount cauris.\n'
            'Nouveau solde: $newBalance cauris\n\n'
            'Vous pouvez maintenant utiliser votre solde pour jouer.',
          );
          
          // ✅ Mettre à jour le solde affiché
          setState(() {
            _currentBalance = newBalance;
          });
        } else if (paymentResult == false) {
          // ✅ Vérifier si c'est une expiration ou une annulation
          final transactions = await PaymentApiService.instance.getTransactions();
          if (transactions['success'] == true) {
            final List data = transactions['data'] as List;
            final lastTransaction = data.isNotEmpty ? data.first : null;
            final status = lastTransaction?['status'] as String?;
            
            if (status == 'rejete' || status == 'en_attente') {
              _showErrorDialog(
                'Paiement expiré ou annulé',
                'Le paiement n\'a pas été validé dans les 3 minutes.\n'
                'Votre transaction a été annulée.\n\n'
                'Vous pouvez réessayer un nouveau dépôt.',
              );
            } else {
              _showErrorDialog(
                'Paiement annulé',
                'Le paiement a été annulé. Vous pouvez réessayer à tout moment.',
              );
            }
          } else {
            _showErrorDialog(
              'Paiement annulé',
              'Le paiement a été annulé. Vous pouvez réessayer à tout moment.',
            );
          }
        }
        // Si paymentResult est null, l'utilisateur a simplement fermé la page
      } else {
        // Si pas d'URL, la transaction a peut-être été créée mais sans URL de redirection
        await Future.wait([
          _loadTransactionsFromBackend(),
          _loadBalanceFromBackend(),
        ]);
        
        setState(() {
          _depotCaurisController.clear();
          _depotPhoneController.clear();
          _calculatedFcfaAmount = 0;
        });
        
        _showSuccessDialog(
          'Transaction créée',
          'Votre demande de dépôt de $caurisInt cauris ($montantFcfa FCFA) a été enregistrée. Vous recevrez une notification une fois le paiement confirmé.',
        );
      }
    } catch (e) {
      // Fermer l'indicateur de chargement en cas d'erreur
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showErrorDialog('Erreur', 'Erreur: $e');
    }
  }

  /// Traiter un retrait
  /// 
  /// 🔄 INTÉGRATION BACKEND :
  /// TODO: Remplacer cette logique locale par un appel API
  /// 
  /// 1. Importer les dépendances :
  /// ```dart
  /// import 'package:http/http.dart' as http;
  /// import 'dart:convert';
  /// import '../../services/user/user_service.dart';
  /// ```
  /// 
  /// 2. Créer un service API :
  /// ```dart
  /// Future<void> _createRetraitAPI({
  ///   required int cauris,
  ///   required int fcfa,
  ///   required String beneficiaire,
  ///   required String phone,
  /// }) async {
  ///   final response = await http.post(
  ///     Uri.parse('$apiUrl/api/transactions/retrait'),
  ///     headers: {
  ///       'Content-Type': 'application/json',
  ///       'Authorization': 'Bearer ${UserService.instance.authToken}',
  ///     },
  ///     body: jsonEncode({
  ///       'type': 'retrait',
  ///       'caurisAmount': cauris,
  ///       'fcfaAmount': fcfa,
  ///       'beneficiaireName': beneficiaire,
  ///       'phoneNumber': phone,
  ///     }),
  ///   );
  ///   
  ///   if (response.statusCode == 201) {
  ///     final data = jsonDecode(response.body);
  ///     _showSuccessDialog('Retrait initié', data['message']);
  ///   }
  /// }
  /// ```
  /// 
  /// 3. ❌ À SUPPRIMER : Ligne 753-762 (simulation locale)
  /// 4. ✅ À CONSERVER : Les validations locales (lignes 691-707)
  Future<void> _handleRetrait() async {
    final nombreCauris = _nombreCaurisController.text.trim();
    final numeroTelephone = _numeroTelephoneController.text.trim();
    final beneficiaireName = _beneficiaireNameController.text.trim();
    
    // ✅ VALIDATION - À CONSERVER
    if (nombreCauris.isEmpty || numeroTelephone.isEmpty || beneficiaireName.isEmpty) {
      _showErrorDialog('Erreur', 'Veuillez remplir tous les champs');
      return;
    }
    
    final caurisInt = int.tryParse(nombreCauris);
    if (caurisInt == null || caurisInt <= 0) {
      _showErrorDialog('Erreur', 'Nombre de cauris invalide');
      return;
    }
    
    if (caurisInt > _currentBalance) {
      _showErrorDialog('Erreur', 'Solde insuffisant');
      return;
    }
    
    // Calculer le montant en FCFA (10 cauris = 1000 FCFA)
    final montantFcfa = (caurisInt / 10 * 1000).round();
    
    // Appel API backend retrait
    final res = await PaymentApiService.instance.withdraw(
      cauris: caurisInt,
      beneficiaryName: beneficiaireName,
      phone: numeroTelephone,
    );
    if (res['success'] != true) {
      _showErrorDialog('Erreur', res['message'] ?? 'Erreur lors du retrait');
      return;
    }
    
    // Recharger l'historique et le solde depuis le backend au lieu d'ajouter localement
    await Future.wait([
      _loadTransactionsFromBackend(),
      _loadBalanceFromBackend(),
    ]);
    
    setState(() {
      _nombreCaurisController.clear();
      _numeroTelephoneController.clear();
      _beneficiaireNameController.clear();
    });
    _showSuccessDialog('Retrait initié',
        'Retrait de $caurisInt cauris ($montantFcfa FCFA) vers $beneficiaireName ($numeroTelephone) en cours.');
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final isDepot = transaction.type == 'depot';
    final statusColor = _getStatusColor(transaction.status);
    final statusText = _getStatusText(transaction.status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF404040),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icône de type de transaction
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDepot ? const Color(0xFF228B22) : Colors.orange,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDepot ? Icons.add : Icons.remove,
              color: Colors.white,
              size: 20,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Détails de la transaction
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDepot ? 'Dépôt' : 'Retrait',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${transaction.cauris} cauris (${transaction.montant} FCFA)',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                // Afficher le nom du bénéficiaire pour les retraits
                if (!isDepot && transaction.beneficiaireName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Bénéficiaire: ${transaction.beneficiaireName}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _formatDate(transaction.date),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Statut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor, width: 1),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'valide':
        return const Color(0xFF228B22); // Vert
      case 'en_attente':
        return const Color(0xFFFFD700); // Jaune
      case 'rejete':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'valide':
        return 'Validé';
      case 'en_attente':
        return 'En attente';
      case 'rejete':
        return 'Rejeté';
      default:
        return 'Inconnu';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String title, [String? message]) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: message != null ? Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ) : null,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

}
