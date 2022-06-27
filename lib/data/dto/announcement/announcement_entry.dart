enum AnnouncementPriority { normal, high }

class AnnouncementEntry {
  /// A unique ID derived for each entry. Typically this is in the form of {owner}/{repo}/issue/{issue number}.
  String entryId;

  /// The url to the full announcement. This is generally a link to an issue on GitHub.
  String url;

  /// Announcement title, will match the title of the issue on GitHub.
  String title;

  /// The first paragraph of the announcement. Anything over 512 characters will be truncated.
  String description;

  /// Can be normal or high. It is recommended that clients immediately alert the user when one or more high priority announcments are present. Issued tagged with the critical label will be assigned a high priority.
  AnnouncementPriority priority;

  /// The announcement creation date in unix time.
  DateTime date;

  /// If set to true this announcement has been previously dismissed
  bool dismissed;

  /// The date the announcement was dismissed in unix time. If the announcement has not been dismissed this value is null.
  DateTime? dateDismissed;

  /// If the announcement was dismissed with a wake_time specified this is the time (in unix time) at which the dismissed state will revert. If the announcement is not dismissed or dismissed indefinitely this value will be null.
  DateTime? dismissWake;

  /// The source from which the announcement was generated. Can be moonlight or internal.
  String source;

  /// The RSS feed for moonlight announcements. For example, this could be Moonraker or Klipper. If the announcement was generated internally this should match the name of the component that generated the announcement.
  String feed;

  AnnouncementEntry.parse(Map<String, dynamic> json)
      : entryId = json['entryId'],
        url = json['url'],
        title = json['title'],
        description = json['description'],
        priority = json['priority'],
        date = DateTime.fromMillisecondsSinceEpoch(json['date'] * 1000),
        dismissed = json['dismissed'],
        dateDismissed = (json.containsKey('date_dismissed'))
            ? json['date_dismissed']
            : null,
        dismissWake =
            (json.containsKey('dismiss_wake')) ? json['dismiss_wake'] : null,
        source = json['source'],
        feed = json['feed'];
}
