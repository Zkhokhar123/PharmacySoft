/// Converts between boxes (daba) and base units (tabs / goli).
///
/// Example: 4 boxes × 50 tabs = 200 tabs in stock.
class PackQty {
  PackQty._();

  static int normalizePackSize(int unitsPerPack) =>
      unitsPerPack <= 0 ? 1 : unitsPerPack;

  static int totalUnits({required int packs, required int unitsPerPack}) =>
      packs * normalizePackSize(unitsPerPack);

  static int fullPacks(int units, int unitsPerPack) {
    final size = normalizePackSize(unitsPerPack);
    return units ~/ size;
  }

  static int remainder(int units, int unitsPerPack) {
    final size = normalizePackSize(unitsPerPack);
    return units % size;
  }

  /// "4 Box (200 Tab)" or "3 Box + 10 Tab (160 Tab)" or "12 Tab".
  static String format(
    int units, {
    int unitsPerPack = 1,
    String unit = 'Tab',
    String packName = 'Box',
  }) {
    final size = normalizePackSize(unitsPerPack);
    if (size <= 1) return '$units $unit';
    final packs = units ~/ size;
    final rem = units % size;
    if (packs == 0) return '$units $unit';
    if (rem == 0) return '$packs $packName ($units $unit)';
    return '$packs $packName + $rem $unit ($units $unit)';
  }

  static double perUnitFromPack(double packPrice, int unitsPerPack) {
    final size = normalizePackSize(unitsPerPack);
    if (packPrice == 0) return 0;
    return packPrice / size;
  }

  static double packFromPerUnit(double unitPrice, int unitsPerPack) =>
      unitPrice * normalizePackSize(unitsPerPack);
}
