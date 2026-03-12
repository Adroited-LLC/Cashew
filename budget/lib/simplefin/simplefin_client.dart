import 'dart:convert';
import 'package:http/http.dart' as http;

class SimplefinAccount {
  final String id;
  final String name;
  final String orgName;
  final String currency;
  final String balance;
  final int balanceDate; // Unix timestamp (seconds)
  final List<SimplefinTransaction> transactions;

  SimplefinAccount({
    required this.id,
    required this.name,
    required this.orgName,
    required this.currency,
    required this.balance,
    required this.balanceDate,
    required this.transactions,
  });

  double get balanceDouble => double.tryParse(balance) ?? 0.0;

  DateTime get balanceDatetime =>
      DateTime.fromMillisecondsSinceEpoch(balanceDate * 1000).toLocal();

  factory SimplefinAccount.fromJson(Map<String, dynamic> json) {
    return SimplefinAccount(
      id: json['id'] as String,
      name: json['name'] as String,
      orgName:
          (json['org'] as Map<String, dynamic>?)?['name'] as String? ?? '',
      currency: json['currency'] as String? ?? 'USD',
      balance: json['balance'] as String? ?? '0',
      balanceDate: json['balance-date'] as int? ?? 0,
      transactions: (json['transactions'] as List<dynamic>? ?? [])
          .map((t) =>
              SimplefinTransaction.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SimplefinTransaction {
  final String id;
  final int posted; // Unix timestamp (seconds); 0 if pending
  final int? transactedAt; // Unix timestamp (seconds); optional
  final String amount; // e.g. "-45.67" or "100.00"
  final String description;
  final bool pending;

  SimplefinTransaction({
    required this.id,
    required this.posted,
    this.transactedAt,
    required this.amount,
    required this.description,
    this.pending = false,
  });

  factory SimplefinTransaction.fromJson(Map<String, dynamic> json) {
    return SimplefinTransaction(
      id: json['id'] as String,
      posted: json['posted'] as int? ?? 0,
      transactedAt: json['transacted_at'] as int?,
      amount: json['amount'] as String,
      description: json['description'] as String? ?? '',
      pending: json['pending'] as bool? ?? false,
    );
  }

  /// Best-effort date: prefer transacted_at, fall back to posted, then now.
  DateTime get date {
    final ts = (posted != 0 ? posted : null) ?? transactedAt;
    if (ts != null && ts != 0) {
      return DateTime.fromMillisecondsSinceEpoch(ts * 1000).toLocal();
    }
    return DateTime.now();
  }

  double get amountDouble => double.tryParse(amount) ?? 0.0;
}

class SimplefinClient {
  /// Exchange a one-time Setup Token for a permanent Access URL.
  ///
  /// Setup Token is a base64url-encoded claim URL. We decode it, then POST
  /// to that URL (no body required). The response body is the Access URL.
  static Future<String> exchangeSetupToken(String setupToken) async {
    final decoded =
        utf8.decode(base64.decode(base64.normalize(setupToken.trim())));
    final response = await http
        .post(Uri.parse(decoded))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw 'Token exchange failed (${response.statusCode}): ${response.body}';
    }
    final accessUrl = response.body.trim();
    if (!accessUrl.startsWith('http')) {
      throw 'Unexpected response from token exchange: $accessUrl';
    }
    return accessUrl;
  }

  /// Fetch accounts + transactions from the Access URL.
  ///
  /// [startDate] adds a `start-date` query param (Unix seconds) to limit
  /// the transaction window and reduce payload size.
  static Future<List<SimplefinAccount>> fetchAccounts(
    String accessUrl, {
    DateTime? startDate,
  }) async {
    final parsed = Uri.parse(accessUrl);

    // Strip credentials from the URL for the request path
    final cleanUrl = parsed.replace(userInfo: '').toString();

    final uri = Uri.parse('$cleanUrl/accounts');
    final queryParams = <String, String>{'pending': '1'};
    if (startDate != null) {
      queryParams['start-date'] =
          (startDate.millisecondsSinceEpoch ~/ 1000).toString();
    }
    final queryUri = uri.replace(queryParameters: queryParams);

    // Build Basic Auth header from userInfo embedded in the Access URL
    final userInfo = parsed.userInfo;
    final credentials = base64.encode(utf8.encode(userInfo));

    final response = await http.get(
      queryUri,
      headers: {'Authorization': 'Basic $credentials'},
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw 'Failed to fetch accounts (${response.statusCode}): ${response.body}';
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final errors = data['errors'] as List<dynamic>? ?? [];
    if (errors.isNotEmpty) {
      throw 'SimpleFIN reported errors: ${errors.join(', ')}';
    }

    return (data['accounts'] as List<dynamic>)
        .map((a) => SimplefinAccount.fromJson(a as Map<String, dynamic>))
        .toList();
  }
}
