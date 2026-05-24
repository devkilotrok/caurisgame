# 📧 Guide d'implémentation des emails - Authentification Cauris

## 📋 Vue d'ensemble

Ce document explique comment implémenter l'envoi d'emails pour :
1. **Confirmation d'inscription** - Email avec code de vérification
2. **Mot de passe oublié** - Email avec code de réinitialisation

## ✅ Fichiers créés

1. **`lib/services/api/auth_api_service.dart`** - Service API pour l'authentification
2. **`lib/interfaces/auth/verify_email_page.dart`** - Page de vérification du code

## 🔧 Implémentation

### Étape 1 : Ajouter la dépendance HTTP

**Fichier** : `pubspec.yaml`
```yaml
dependencies:
  http: ^1.1.0  # ✅ À AJOUTER
```

### Étape 2 : Implémenter la création de profil

**Fichier** : `lib/interfaces/auth/signup_page.dart`

**Ajouter** :
```dart
import '../../services/api/auth_api_service.dart';
import 'verify_email_page.dart';

/// Gérer la création de profil et l'envoi de l'email
Future<void> _handleSignup() async {
  // Validation
  if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Veuillez remplir tous les champs')),
    );
    return;
  }

  try {
    final authService = AuthApiService.instance;
    
    // Appeler l'API pour créer le compte et envoyer l'email
    final result = await authService.registerWithEmail(
      pseudo: _pseudoController.text,
      email: _emailController.text,
      password: _passwordController.text,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      phone: _phoneController.text,
    );

    if (result['success'] == true) {
      // Rediriger vers la page de vérification
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VerifyEmailPage(
            email: _emailController.text,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'])),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur: $e')),
    );
  }
}
```

### Étape 3 : Implémenter le mot de passe oublié

**Fichier** : `lib/interfaces/auth/forgot_password_page.dart`

**Ajouter** :
```dart
import '../../services/api/auth_api_service.dart';
import 'reset_password_page.dart'; // À créer

/// Gérer l'envoi du code de réinitialisation
Future<void> _handleForgotPassword() async {
  if (_emailController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Veuillez saisir votre email')),
    );
    return;
  }

  try {
    final authService = AuthApiService.instance;
    
    // Appeler l'API pour envoyer le code par email
    final result = await authService.requestPasswordReset(
      email: _emailController.text,
    );

    if (result['success'] == true) {
      // Rediriger vers la page de saisie du code
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VerifyResetCodePage(
            email: _emailController.text,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'])),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur: $e')),
    );
  }
}
```

### Étape 4 : Implémenter la vérification du code

**Fichier** : `lib/interfaces/auth/verify_email_page.dart`

**Modifier** la méthode `_verifyCode()` :
```dart
Future<void> _verifyCode() async {
  setState(() => _isLoading = true);
  
  try {
    final authService = AuthApiService.instance;
    
    // Vérifier le code
    final result = await authService.verifyEmailCode(
      email: widget.email,
      code: _codeController.text,
    );

    if (result['success'] == true) {
      // Sauvegarder le token et se connecter automatiquement
      final token = result['token'];
      final user = result['user'];
      
      await UserService.instance.login(user['pseudo'], widget.email);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email vérifié avec succès !'),
            backgroundColor: Color(0xFF228B22),
          ),
        );
        
        // Naviguer vers la page d'accueil
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  } finally {
    setState(() => _isLoading = false);
  }
}
```

## 🎯 Backend Laravel - Endpoints requis

### 1. POST /api/auth/register
**Fonctionnalité** : Créer un compte et envoyer le code par email

**Request** :
```json
{
  "pseudo": "John",
  "email": "john@example.com",
  "password": "password123",
  "first_name": "John",
  "last_name": "Doe"
}
```

**Response** :
```json
{
  "success": true,
  "message": "Code de vérification envoyé par email",
  "user": {
    "id": 1,
    "pseudo": "John",
    "email": "john@example.com"
  }
}
```

### 2. POST /api/auth/verify-email
**Fonctionnalité** : Vérifier le code et activer le compte

**Request** :
```json
{
  "email": "john@example.com",
  "code": "123456"
}
```

**Response** :
```json
{
  "success": true,
  "message": "Email vérifié",
  "token": "jwt_token_here"
}
```

### 3. POST /api/auth/forgot-password
**Fonctionnalité** : Envoyer le code de réinitialisation

**Request** :
```json
{
  "email": "john@example.com"
}
```

**Response** :
```json
{
  "success": true,
  "message": "Code de réinitialisation envoyé par email"
}
```

### 4. POST /api/auth/verify-reset-code
**Fonctionnalité** : Vérifier le code de réinitialisation

**Request** :
```json
{
  "email": "john@example.com",
  "code": "123456"
}
```

**Response** :
```json
{
  "success": true,
  "resetToken": "temporary_token_here"
}
```

### 5. POST /api/auth/reset-password
**Fonctionnalité** : Réinitialiser le mot de passe

**Request** :
```json
{
  "email": "john@example.com",
  "resetToken": "temporary_token_here",
  "password": "new_password123"
}
```

**Response** :
```json
{
  "success": true,
  "message": "Mot de passe réinitialisé avec succès"
}
```

## 📧 Configuration de l'envoi d'emails

### Dans Laravel (backend)

**Fichier** : `.env`
```env
MAIL_MAILER=smtp
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=your-app-password
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=noreply@cauris.com
MAIL_FROM_NAME="Cauris"
```

**Fichier** : `app/Mail/VerificationEmail.php`
```php
<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Queue\SerializesModels;

class VerificationEmail extends Mailable
{
    use Queueable, SerializesModels;

    public $code;
    public $userName;

    public function __construct($code, $userName)
    {
        $this->code = $code;
        $this->userName = $userName;
    }

    public function build()
    {
        return $this->subject('Vérification de votre compte Cauris')
                    ->view('emails.verification');
    }
}
```

**Template** : `resources/views/emails/verification.blade.php`
```html
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .code { background: #f4f4f4; padding: 20px; text-align: center; font-size: 32px; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Bienvenue sur Cauris !</h1>
        <p>Bonjour {{ $userName }},</p>
        <p>Votre code de vérification est :</p>
        <div class="code">{{ $code }}</div>
        <p>Ce code expirera dans 24 heures.</p>
    </div>
</body>
</html>
```

## ✅ Checklist

### Frontend Flutter
- [x] Créer `AuthApiService`
- [x] Créer `VerifyEmailPage`
- [ ] Implémenter `_handleSignup()` dans `signup_page.dart`
- [ ] Implémenter `_handleForgotPassword()` dans `forgot_password_page.dart`
- [ ] Ajouter la dépendance `http` dans `pubspec.yaml`
- [ ] Tester l'inscription
- [ ] Tester la vérification email
- [ ] Tester le mot de passe oublié

### Backend Laravel
- [ ] Configurer `.env` pour l'email
- [ ] Créer `VerificationEmail` Mailable
- [ ] Créer `PasswordResetEmail` Mailable
- [ ] Implémenter les endpoints dans `AuthController`
- [ ] Tester l'envoi d'emails
- [ ] Configurer la queue pour les emails (optionnel)

## 🎯 Résumé

**Frontend** : Les services et pages sont créés, il reste à les connecter
**Backend** : À implémenter dans Laravel avec l'envoi d'emails SMTP
**Email** : Configuration SMTP nécessaire (Gmail, SendGrid, etc.)

