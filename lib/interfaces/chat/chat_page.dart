import 'package:flutter/material.dart';
import '../../services/api/chat_api_service.dart';
import '../../services/user/user_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatApiService _chatService = ChatApiService.instance;

  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _conversation;
  bool _isLoading = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadConversation();
  }

  @override
  void dispose() {
    // Fermer la conversation quand l'utilisateur quitte le chat
    if (_conversation != null && _conversation!['id'] != null) {
      _chatService.closeConversation(_conversation!['id']).catchError((e) {
        print('Erreur lors de la fermeture de la conversation: $e');
      });
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversation() async {
    setState(() => _isLoading = true);

    try {
      final result = await _chatService.getOrCreateConversation();
      if (result['success'] == true && mounted) {
        setState(() {
          _conversation = result['conversation'];
          _messages = List<Map<String, dynamic>>.from(result['messages'] ?? []);
          _isLoading = false;
        });
        _scrollToBottom();
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorDialog(result['message'] ?? 'Erreur lors du chargement');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog('Erreur: $e');
      }
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _conversation == null || _isSending) return;

    setState(() {
      _isSending = true;
      _messageController.clear();
    });

    // Ajouter le message de l'utilisateur immédiatement
    final userMessage = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'sender_type': 'user',
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
    };
    setState(() {
      _messages.add(userMessage);
    });
    _scrollToBottom();

    try {
      final result = await _chatService.sendMessage(
        conversationId: _conversation!['id'],
        message: message,
      );

      if (result['success'] == true && mounted) {
        // Mettre à jour le message utilisateur et ajouter la réponse de l'IA
        setState(() {
          if (result['user_message'] != null) {
            final index = _messages.indexWhere((m) => m['id'] == userMessage['id']);
            if (index != -1) {
              _messages[index] = result['user_message'];
            }
          }
          if (result['ai_message'] != null) {
            _messages.add(result['ai_message']);
          }
          // Mettre à jour le statut de la conversation si elle a changé
          if (result['conversation_updated'] != null) {
            final updated = Map<String, dynamic>.from(_conversation ?? {});
            updated.addAll(result['conversation_updated'] as Map<String, dynamic>);
            _conversation = updated;
          }
        });
        _scrollToBottom();
      } else {
        // En cas d'erreur, retirer le message utilisateur ajouté
        setState(() {
          _messages.removeWhere((m) => m['id'] == userMessage['id']);
        });
        if (mounted) {
          _showErrorDialog(result['message'] ?? 'Erreur lors de l\'envoi');
        }
      }
    } catch (e) {
      // En cas d'erreur, retirer le message utilisateur ajouté
      setState(() {
        _messages.removeWhere((m) => m['id'] == userMessage['id']);
      });
      if (mounted) {
        _showErrorDialog('Erreur: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _requestManager() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contacter un manager'),
        content: const Text(
          'Voulez-vous être mis en contact avec un manager humain ? '
          'Un membre de notre équipe vous répondra bientôt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final result = await _chatService.requestManager();
        if (result['success'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Votre demande a été transmise à un manager'),
              backgroundColor: Colors.green,
            ),
          );
          // Recharger la conversation
          _loadConversation();
        } else {
          if (mounted) {
            _showErrorDialog(result['message'] ?? 'Erreur lors de la demande');
          }
        }
      } catch (e) {
        if (mounted) {
          _showErrorDialog('Erreur: $e');
        }
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erreur'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.smart_toy, color: Color(0xFF228B22)),
            const SizedBox(width: 8),
            const Text(
              'Assistance',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (_conversation != null && _conversation!['assistant_type'] == 'manager')
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Manager',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
          ],
        ),
        actions: [
          if (_conversation != null && _conversation!['assistant_type'] == 'ai')
            IconButton(
              icon: const Icon(Icons.person, color: Color(0xFF228B22)),
              onPressed: _requestManager,
              tooltip: 'Contacter un manager',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Zone des messages
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: isDark ? Colors.grey[600] : Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Bonjour ! Comment puis-je vous aider ?',
                                style: TextStyle(
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isUser = message['sender_type'] == 'user';
                            return _buildMessageBubble(message, isUser, isDark);
                          },
                        ),
                ),
                // Zone de saisie
                _buildInputArea(isDark),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isUser, bool isDark) {
    final senderName = isUser
        ? (UserService.instance.currentUserPseudo ?? 'Vous')
        : (message['sender_type'] == 'ai' ? 'Assistant IA' : 'Manager');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF228B22),
              child: Icon(
                message['sender_type'] == 'ai' ? Icons.smart_toy : Icons.person,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF228B22)
                    : (isDark ? Colors.grey[800] : Colors.white),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser)
                    Text(
                      senderName,
                      style: TextStyle(
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (!isUser) const SizedBox(height: 4),
                  Text(
                    message['message'] ?? '',
                    style: TextStyle(
                      color: isUser ? Colors.white : (isDark ? Colors.white : Colors.black),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[700],
              child: const Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Tapez votre message...',
                  hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF228B22),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: _isSending ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

