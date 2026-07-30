/// Represents a discovered TV on the local network.
enum TVBrand { samsung, lg, androidTV, roku, unknown }

class TVDevice {
  final String name;
  final String ip;
  final int port;
  final TVBrand brand;
  final String? macAddress;
  String? pairingToken; // Samsung token, LG client key, or Android TV cert

  TVDevice({
    required this.name,
    required this.ip,
    required this.port,
    required this.brand,
    this.macAddress,
    this.pairingToken,
  });

  String get brandLabel {
    switch (brand) {
      case TVBrand.samsung:
        return 'Samsung';
      case TVBrand.lg:
        return 'LG';
      case TVBrand.androidTV:
        return 'Android TV';
      case TVBrand.roku:
        return 'Roku';
      case TVBrand.unknown:
        return 'Unknown';
    }
  }

  String get id => '${brand.name}_$ip';

  Map<String, dynamic> toJson() => {
    'name': name,
    'ip': ip,
    'port': port,
    'brand': brand.name,
    'macAddress': macAddress,
    'pairingToken': pairingToken,
  };

  factory TVDevice.fromJson(Map<String, dynamic> json) => TVDevice(
    name: json['name'] as String,
    ip: json['ip'] as String,
    port: json['port'] as int,
    brand: TVBrand.values.firstWhere((b) => b.name == json['brand']),
    macAddress: json['macAddress'] as String?,
    pairingToken: json['pairingToken'] as String?,
  );
}
