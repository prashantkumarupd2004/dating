class ListenerModel {
  final String id;
  final String displayName;
  final String? photoUrl;
  final int? age;
  final String? city;
  final String? state;
  final String? relationshipStatus;
  final String onlineStatus;
  final String status;
  final bool isAudioEnabled;
  final bool isVideoEnabled;
  final double rating;
  final int totalCalls;
  final List<String> languages;
  final String? bio;
  final String? quote;
  final String? expertise;
  final double pricePerMin;
  final bool isVerified;
  final bool isFavorite;
  final bool isFeatured;

  const ListenerModel({
    required this.id,
    required this.displayName,
    this.photoUrl,
    this.age,
    this.city,
    this.state,
    this.relationshipStatus,
    required this.onlineStatus,
    required this.status,
    required this.isAudioEnabled,
    required this.isVideoEnabled,
    required this.rating,
    required this.totalCalls,
    required this.languages,
    this.bio,
    this.quote,
    this.expertise,
    this.pricePerMin = 1.0,
    this.isVerified = false,
    this.isFavorite = false,
    this.isFeatured = false,
  });

  bool get isOnline => onlineStatus == 'ONLINE';
  bool get isBusy => onlineStatus == 'BUSY';
  bool get isOffline => onlineStatus == 'OFFLINE';

  String get primaryLanguage => languages.isNotEmpty ? languages.first : 'Hindi';

  String get locationDisplay {
    if (city != null && state != null) return '$city, $state';
    if (city != null) return city!;
    if (state != null) return state!;
    return '';
  }

  factory ListenerModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>?;
    final dob = profile?['dateOfBirth'] as String?;
    int? age;
    if (dob != null) {
      final birthDate = DateTime.parse(dob);
      age = DateTime.now().difference(birthDate).inDays ~/ 365;
    }
    return ListenerModel(
      id: json['id'] as String,
      displayName: profile?['displayName'] as String? ?? json['user']?['name'] ?? 'Unknown',
      photoUrl: profile?['photoUrl'] as String?,
      age: age,
      city: profile?['city'] as String?,
      state: profile?['state'] as String?,
      relationshipStatus: profile?['relationshipStatus'] as String?,
      onlineStatus: json['onlineStatus'] as String? ?? 'OFFLINE',
      status: json['status'] as String? ?? 'APPROVED',
      isAudioEnabled: json['isAudioEnabled'] as bool? ?? true,
      isVideoEnabled: json['isVideoEnabled'] as bool? ?? false,
      rating: (profile?['rating'] as num?)?.toDouble() ?? 0.0,
      totalCalls: profile?['totalCalls'] as int? ?? 0,
      languages: List<String>.from(profile?['languages'] ?? []),
      bio: profile?['bio'] as String?,
      quote: profile?['quote'] as String?,
      expertise: profile?['expertise'] as String?,
      pricePerMin: (profile?['pricePerMin'] as num?)?.toDouble() ?? 1.0,
      isFeatured: json['isFeatured'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }
}

class CallModel {
  final String id;
  final String listenerId;
  final String listenerName;
  final String? listenerPhoto;
  final String type;
  final String status;
  final int? durationSeconds;
  final double? coinsDeducted;
  final DateTime createdAt;

  const CallModel({
    required this.id,
    required this.listenerId,
    required this.listenerName,
    this.listenerPhoto,
    required this.type,
    required this.status,
    this.durationSeconds,
    this.coinsDeducted,
    required this.createdAt,
  });

  factory CallModel.fromJson(Map<String, dynamic> json) {
    final listener = json['listener'] as Map<String, dynamic>?;
    final profile = listener?['profile'] as Map<String, dynamic>?;

    // Safe int parser — backend may return int or String
    int? safeInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    // Safe double parser — Prisma Decimal serializes as String
    double? safeDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return CallModel(
      id: json['id'] as String,
      listenerId: json['listenerId'] as String,
      listenerName: profile?['displayName'] as String? ?? 'Unknown',
      listenerPhoto: profile?['photoUrl'] as String?,
      type: json['type'] as String,
      status: json['status'] as String,
      durationSeconds: safeInt(json['durationSeconds']),
      coinsDeducted: safeDouble(json['billing']?['coinsDeducted']),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class WalletModel {
  final double balance;
  final List<WalletTransaction> transactions;

  const WalletModel({required this.balance, required this.transactions});

  factory WalletModel.fromJson(Map<String, dynamic> json) => WalletModel(
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
        transactions: (json['transactions'] as List<dynamic>?)
                ?.map((t) => WalletTransaction.fromJson(t))
                .toList() ??
            [],
      );
}

class WalletTransaction {
  final String id;
  final String type;
  final double amount;
  final String? description;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.description,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) => WalletTransaction(
        id: json['id'] as String,
        type: json['type'] as String,
        amount: (json['amount'] as num).toDouble(),
        description: json['description'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class CoinPackage {
  final String id;
  final String name;
  final int coins;
  final int bonusCoins;
  final double priceInr;
  final double? originalPriceInr;
  final String? badge;

  const CoinPackage({
    required this.id,
    required this.name,
    required this.coins,
    required this.bonusCoins,
    required this.priceInr,
    this.originalPriceInr,
    this.badge,
  });

  int get totalCoins => coins + bonusCoins;
  bool get hasDiscount => originalPriceInr != null && originalPriceInr! > priceInr;
  int get discountAmount => hasDiscount ? (originalPriceInr! - priceInr).round() : 0;

  factory CoinPackage.fromJson(Map<String, dynamic> json) => CoinPackage(
        id: json['id'] as String,
        name: json['name'] as String,
        coins: json['coins'] as int,
        bonusCoins: json['bonusCoins'] as int? ?? 0,
        priceInr: double.tryParse(json['priceInr'].toString()) ?? 0,
        originalPriceInr: json['originalPriceInr'] != null
            ? double.tryParse(json['originalPriceInr'].toString())
            : null,
        badge: json['badge'] as String?,
      );
}

