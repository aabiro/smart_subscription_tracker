class GmailParser {
  // Simulated email messages
  final List<String> fakeEmails = [
    'Your Netflix subscription of \$15.99 has been renewed.',
    'Spotify Premium: \$9.99/month charged to your account.',
    'You subscribed to ChatGPT Plus - \$20 monthly.',
  ];

  // Simulate parsing subscription data
  List<Map<String, dynamic>> parseEmails() {
    final parsed = <Map<String, dynamic>>[];

    for (var email in fakeEmails) {
      if (email.contains('Netflix')) {
        parsed.add(_buildSub('Netflix', 15.99));
      } else if (email.contains('Spotify')) {
        parsed.add(_buildSub('Spotify', 9.99));
      } else if (email.contains('ChatGPT')) {
        parsed.add(_buildSub('ChatGPT Plus', 20.0));
      }
    }

    return parsed;
  }

  Map<String, dynamic> _buildSub(String name, double price) {
    return {
      'name': name,
      'price': price,
      'billingCycle': 'Monthly',
      'nextPaymentDate': DateTime.now().add(Duration(days: 30)),
    };
  }
}
