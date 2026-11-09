enum BooruError {
  empty,
  tagsBlocked,

  /// The server refused the request because it needs API credentials
  authRequired,

  /// Content hidden because NSFW is disabled
  nsfwDisabled,
}
