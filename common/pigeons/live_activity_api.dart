/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:pigeon/pigeon.dart';

// Regenerate with (from common/): dart run pigeon --input pigeons/live_activity_api.dart
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/service/live_activity/live_activity_api.pigeon.dart',
    swiftOut: '../ios/Runner/LiveActivity/LiveActivityApi.g.swift',
    dartPackageName: 'common',
  ),
)
/// Static data of a live activity. Mirrors `LiveActivitiesAppAttributes` on iOS.
/// Can not be changed after the activity was started.
class LiveActivityAttributesMessage {
  LiveActivityAttributesMessage({
    required this.machineUUID,
    required this.machineName,
    required this.colorLight,
    required this.colorDark,
    required this.etaLabel,
    required this.remainingLabel,
    required this.stateLabels,
  });

  String machineUUID;
  String machineName;
  int colorLight;
  int colorDark;
  String etaLabel;
  String remainingLabel;

  /// PrintState.name -> localized label
  Map<String, String> stateLabels;
}

/// Dynamic data of a live activity. Mirrors `LiveActivitiesAppAttributes.ContentState` on iOS.
class LiveActivityContentMessage {
  LiveActivityContentMessage({this.progress, this.eta, this.printState, this.file});

  double? progress;

  /// Seconds since epoch
  int? eta;
  String? printState;
  String? file;
}

enum LiveActivityStateMessage { active, stale, ended, dismissed }

class LiveActivityInfoMessage {
  LiveActivityInfoMessage({
    required this.activityId,
    required this.machineUUID,
    required this.state,
    this.pushToken,
  });

  String activityId;

  /// Null for activities that can not be mapped to a machine (e.g. started by an older app version)
  String? machineUUID;
  LiveActivityStateMessage state;
  String? pushToken;
}

@HostApi()
abstract class LiveActivityHostApi {
  /// Whether the OS supports live activities and the user allowed them.
  bool areActivitiesEnabled();

  /// All activities of this app currently known to the OS.
  List<LiveActivityInfoMessage> getActivities();

  /// Updates the running activity of the machine or creates a new one if none is running.
  /// Returns the activity id.
  @async
  String createOrUpdate(LiveActivityAttributesMessage attributes, LiveActivityContentMessage content);

  /// Ends all activities of the machine.
  @async
  void end(String machineUUID, LiveActivityContentMessage? finalContent, bool dismissImmediately);

  /// Ends all activities that do not belong to one of the given machines.
  @async
  void endAllExcept(List<String> machineUUIDs);

  /// The token that allows starting an activity via push (iOS 17.2+). Null if not (yet) available.
  String? getPushToStartToken();

  /// Stores the (downscaled) thumbnail of [fileName] in the App Group container, replacing the previous one of the machine.
  /// The widget shows it as long as the activity's `file` matches [fileName].
  @async
  void setThumbnail(String machineUUID, String fileName, Uint8List image);
}

sealed class LiveActivityEvent {}

/// The push token of an activity changed. Emitted for all known activities when Dart starts listening.
class LiveActivityTokenEvent extends LiveActivityEvent {
  LiveActivityTokenEvent({required this.activityId, this.machineUUID, required this.token});

  String activityId;
  String? machineUUID;
  String token;
}

class LiveActivityStateEvent extends LiveActivityEvent {
  LiveActivityStateEvent({required this.activityId, this.machineUUID, required this.state});

  String activityId;
  String? machineUUID;
  LiveActivityStateMessage state;
}

/// The push-to-start token changed (iOS 17.2+). Emitted with the current token when Dart starts listening.
class LiveActivityPushToStartTokenEvent extends LiveActivityEvent {
  LiveActivityPushToStartTokenEvent({required this.token});

  String token;
}

@EventChannelApi()
abstract class LiveActivityEventApi {
  LiveActivityEvent liveActivityEvents();
}
