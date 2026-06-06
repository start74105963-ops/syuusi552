class MachineModel {
  final String id;
  final String name;
  final String? maker;
  final String? category;

  const MachineModel({
    required this.id,
    required this.name,
    this.maker,
    this.category,
  });

  factory MachineModel.fromMap(Map<String, dynamic> m) => MachineModel(
        id: m['id'] as String,
        name: m['name'] as String,
        maker: m['maker'] as String?,
        category: m['category'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'maker': maker,
        'category': category,
      };
}
