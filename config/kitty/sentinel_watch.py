import shlex


started = {}
notices = {}


def executable_name(command):
    try:
        tokens = shlex.split(command)
    except ValueError:
        return "Command"
    for token in tokens:
        if "=" not in token and not token.startswith("-"):
            return token.rsplit("/", 1)[-1][:48] or "Command"
    return "Command"


def completion(command, status, duration):
    result = "Complete" if str(status) == "0" else "Failed (exit " + str(status) + ")"
    elapsed = f"{duration:.0f}s" if duration < 60 else f"{int(duration // 60)}m {int(duration % 60):02d}s"
    return "Sentinel | " + result, executable_name(command) + " | " + elapsed


def on_cmd_startstop(boss, window, data):
    if data["is_start"]:
        started[window.id] = data["time"]
        return
    beginning = started.pop(window.id, None)
    if beginning is None:
        return
    duration = data["time"] - beginning
    if duration < 20:
        return
    from kitty.notifications import OnlyWhen
    manager = boss.notification_manager
    notification = manager.create_notification_cmd()
    notification.only_when = OnlyWhen.invisible
    notification.title, notification.body = completion(data.get("cmdline", ""), data.get("exit_status", "?"), duration)
    if not manager.is_notification_allowed(notification, window.id):
        return
    previous = notices.pop(window.id, None)
    if previous is not None:
        manager.close_notification(previous)
    identifier = manager.notify_with_command(notification, window.id)
    if identifier is not None:
        notices[window.id] = identifier


def on_focus_change(boss, window, data):
    if data.get("focused"):
        identifier = notices.pop(window.id, None)
        if identifier is not None:
            boss.notification_manager.close_notification(identifier)


def on_close(boss, window, data):
    started.pop(window.id, None)
    identifier = notices.pop(window.id, None)
    if identifier is not None:
        boss.notification_manager.close_notification(identifier)