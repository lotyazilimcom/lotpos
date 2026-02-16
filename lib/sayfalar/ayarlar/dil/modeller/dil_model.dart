class DilModel implements Comparable<DilModel> {
  final int id;
  final String name;
  final String code;
  final bool isDefault;
  final bool isActive;

  DilModel(this.id, this.name, this.code, this.isDefault, this.isActive);

  @override
  int compareTo(DilModel other) {
    return name.compareTo(other.name);
  }
}
