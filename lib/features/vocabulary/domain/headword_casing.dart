// Vocab bank headwords are stored with a capital first letter ("Follow up",
// not "follow up") for consistent display. Applied on every new save and by
// the one-off scripts/capitalize-vocab-headwords.js migration. Idempotent;
// leaves already-capitalized, acronym, and non-letter-initial words alone.
String capitalizeHeadword(String s) {
  if (s.isEmpty) return s;
  final first = s[0];
  if (first.toLowerCase() == first && first.toUpperCase() != first) {
    return first.toUpperCase() + s.substring(1);
  }
  return s;
}
