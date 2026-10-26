class SchoolModel {
  final String id;
  final String name;
  final String? logoUrl;
  final String? address;
  final String? phone;
  final String? email;
  final String? code;
  final String? primaryColor;
  final String? secondaryColor;
  final DateTime createdAt;

  SchoolModel({
    required this.id,
    required this.name,
    this.logoUrl,
    this.address,
    this.phone,
    this.email,
    this.code,
    this.primaryColor,
    this.secondaryColor,
    required this.createdAt,
  });

  factory SchoolModel.fromJson(Map<String, dynamic> json) {
    return SchoolModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      logoUrl: json['logo_url'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      code: json['code'] as String?,
      primaryColor: json['primary_color'] as String?,
      secondaryColor: json['secondary_color'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
