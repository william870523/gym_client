enum PulsoPaletteId {
  clay('arcilla', 'Arcilla'),
  midnight('medianoche', 'Medianoche'),
  ironGold('hierro', 'Hierro y oro');

  const PulsoPaletteId(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static PulsoPaletteId fromStorage(String? value) {
    return PulsoPaletteId.values.firstWhere(
      (palette) => palette.storageValue == value,
      orElse: () => PulsoPaletteId.clay,
    );
  }
}
