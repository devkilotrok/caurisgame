// Modèle pour représenter un utilisateur
class User {
  final String id;
  final String pseudo;
  final String email;
  final int caurisBalance;
  final String avatar;
  final DateTime lastSeen;
  final bool isOnline;

  User({
    required this.id,
    required this.pseudo,
    required this.email,
    required this.caurisBalance,
    required this.avatar,
    required this.lastSeen,
    required this.isOnline,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      pseudo: json['pseudo'],
      email: json['email'],
      caurisBalance: json['caurisBalance'],
      avatar: json['avatar'],
      lastSeen: DateTime.parse(json['lastSeen']),
      isOnline: json['isOnline'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pseudo': pseudo,
      'email': email,
      'caurisBalance': caurisBalance,
      'avatar': avatar,
      'lastSeen': lastSeen.toIso8601String(),
      'isOnline': isOnline,
    };
  }
}

// Modèle pour représenter une relation d'amitié
class Friend {
  final String id;
  final String userId;
  final String friendId;
  final String friendPseudo;
  final String friendAvatar;
  final bool isOnline;
  final DateTime lastSeen;
  final DateTime friendshipDate;

  Friend({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.friendPseudo,
    required this.friendAvatar,
    required this.isOnline,
    required this.lastSeen,
    required this.friendshipDate,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'],
      userId: json['userId'],
      friendId: json['friendId'],
      friendPseudo: json['friendPseudo'],
      friendAvatar: json['friendAvatar'],
      isOnline: json['isOnline'],
      lastSeen: DateTime.parse(json['lastSeen']),
      friendshipDate: DateTime.parse(json['friendshipDate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'friendId': friendId,
      'friendPseudo': friendPseudo,
      'friendAvatar': friendAvatar,
      'isOnline': isOnline,
      'lastSeen': lastSeen.toIso8601String(),
      'friendshipDate': friendshipDate.toIso8601String(),
    };
  }
}

// Modèle pour représenter une demande d'amitié
class FriendRequest {
  final String id;
  final String fromUserId;
  final String fromUserPseudo;
  final String fromUserAvatar;
  final String toUserId;
  final DateTime timestamp;
  final String message;

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUserPseudo,
    required this.fromUserAvatar,
    required this.toUserId,
    required this.timestamp,
    required this.message,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['request_id']?.toString() ?? json['id']?.toString() ?? '',
      fromUserId: json['from_user_id']?.toString() ?? json['fromUserId']?.toString() ?? '',
      fromUserPseudo: json['from_user_pseudo'] ?? json['fromUserPseudo'] ?? 'Unknown',
      fromUserAvatar: json['from_user_avatar'] ?? json['fromUserAvatar'] ?? '👤',
      toUserId: json['to_user_id']?.toString() ?? json['toUserId']?.toString() ?? '',
      timestamp: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : (json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now()),
      message: json['message'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'fromUserPseudo': fromUserPseudo,
      'fromUserAvatar': fromUserAvatar,
      'toUserId': toUserId,
      'timestamp': timestamp.toIso8601String(),
      'message': message,
    };
  }
}

// Modèle pour représenter une invitation à un salon
class RoomInvitation {
  final String id;
  final String roomId;
  final String roomName;
  final String roomCode;
  final String hostId;
  final String hostPseudo;
  final String hostAvatar;
  final String invitedUserId;
  final int minimumBet;
  final DateTime timestamp;
  final String message;

  RoomInvitation({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.roomCode,
    required this.hostId,
    required this.hostPseudo,
    required this.hostAvatar,
    required this.invitedUserId,
    required this.minimumBet,
    required this.timestamp,
    required this.message,
  });

  factory RoomInvitation.fromJson(Map<String, dynamic> json) {
    return RoomInvitation(
      id: json['id'],
      roomId: json['roomId'],
      roomName: json['roomName'],
      roomCode: json['roomCode'],
      hostId: json['hostId'],
      hostPseudo: json['hostPseudo'],
      hostAvatar: json['hostAvatar'],
      invitedUserId: json['invitedUserId'],
      minimumBet: json['minimumBet'],
      timestamp: DateTime.parse(json['timestamp']),
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'roomName': roomName,
      'roomCode': roomCode,
      'hostId': hostId,
      'hostPseudo': hostPseudo,
      'hostAvatar': hostAvatar,
      'invitedUserId': invitedUserId,
      'minimumBet': minimumBet,
      'timestamp': timestamp.toIso8601String(),
      'message': message,
    };
  }
}
