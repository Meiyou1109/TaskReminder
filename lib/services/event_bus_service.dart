import 'package:event_bus/event_bus.dart';

class EventBusService {
  static final EventBus _eventBus = EventBus();

  static EventBus get instance => _eventBus;

  static Stream<T> on<T>() => _eventBus.on<T>();

  static Stream<Object> onAny(List<Type> eventTypes) {
    return _eventBus
        .on<Object>()
        .where((event) => eventTypes.contains(event.runtimeType));
  }

  static void fire(dynamic event) => _eventBus.fire(event);
}

extension EventBusExtensions on EventBusService {
  static Stream<dynamic> onAny(List<Type> types) {
    return EventBusService._eventBus
        .on<dynamic>()
        .where((event) => types.contains(event.runtimeType));
  }
}

