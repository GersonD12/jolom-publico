import 'package:cloud_firestore/cloud_firestore.dart';

/// Convierte un valor Firestore Timestamp / DateTime a [DateTime].
DateTime? parseFirestoreDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  return null;
}

DateTime requireFirestoreDate(Object? value, {DateTime? fallback}) {
  return parseFirestoreDate(value) ??
      fallback ??
      DateTime.fromMillisecondsSinceEpoch(0);
}
