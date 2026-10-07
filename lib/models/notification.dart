class AppNotification {
  final String id, email, title, body, kind; // kind: approval | info | reminder
  final DateTime time;
  final bool read;

  const AppNotification({
    required this.id,
    required this.email,
    required this.title,
    required this.body,
    required this.kind,
    required this.time,
    required this.read,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        email: email,
        title: title,
        body: body,
        kind: kind,
        time: time,
        read: read ?? this.read,
      );
}
