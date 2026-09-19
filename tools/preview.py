import argparse
import os
import sys
from pathlib import Path

from PySide6.QtCore import QFileSystemWatcher, QTimer, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from wallpaper_palette import attach_palette_backend


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the shared QML preview in Qt.")
    parser.add_argument("--smoke", action="store_true")
    parser.add_argument("--watch", action="store_true")
    parser.add_argument("--capture", type=Path)
    parser.add_argument("--ultrawide", action="store_true")
    parser.add_argument("--one-to-one", action="store_true")
    parser.add_argument("--specimen", action="store_true")
    parser.add_argument("--width", type=int, default=1440)
    parser.add_argument("--height", type=int, default=900)
    args = parser.parse_args()
    os.environ.setdefault("QT_QUICK_BACKEND", "software")
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
    app = QGuiApplication(sys.argv[:1])
    app.setOrganizationName("CustomQuickshell")
    app.setApplicationName("Preview")
    engine = QQmlApplicationEngine()
    warnings = []
    engine.warnings.connect(lambda messages: warnings.extend(str(message) for message in messages))
    root = Path(__file__).resolve().parents[1]
    source = root / "preview" / "QtHost.qml"
    initial_properties = {
        "ultrawide": args.ultrawide,
        "oneToOne": args.one_to_one,
        "specimenVisible": args.specimen,
        "width": max(880, args.width),
        "height": max(600, args.height),
    }
    engine.setInitialProperties(initial_properties)
    engine.load(QUrl.fromLocalFile(str(source)))
    if not engine.rootObjects():
        return 1
    palette_backend = attach_palette_backend(engine)
    if args.watch:
        app.setQuitOnLastWindowClosed(False)
        reloading = False
        watcher = QFileSystemWatcher()
        debounce = QTimer()
        debounce.setSingleShot(True)
        debounce.setInterval(150)

        def watch_sources() -> None:
            paths = [str(path) for folder in (root / "shell", root / "preview")
                     for path in folder.rglob("*")
                     if path.is_dir() or path.suffix == ".qml" or path.name == "qmldir"]
            existing = set(watcher.files() + watcher.directories())
            new_paths = [path for path in paths if path not in existing]
            if new_paths:
                watcher.addPaths(new_paths)

        def reload_sources() -> None:
            nonlocal reloading
            reloading = True
            for window in engine.rootObjects():
                window.close()
            engine.deleteLater()
            QTimer.singleShot(0, load_sources)

        def load_sources() -> None:
            nonlocal engine, reloading, palette_backend
            engine = QQmlApplicationEngine()
            engine.warnings.connect(lambda messages: warnings.extend(str(message) for message in messages))
            engine.setInitialProperties(initial_properties)
            engine.load(QUrl.fromLocalFile(str(source)))
            palette_backend = attach_palette_backend(engine)
            watch_sources()
            reloading = False
            if engine.rootObjects():
                connect_close(engine.rootObjects()[-1])
                print("Preview reloaded", flush=True)

        def connect_close(window) -> None:
            def handle_visibility() -> None:
                if not reloading and not window.isVisible():
                    app.quit()
            window.visibleChanged.connect(handle_visibility)

        debounce.timeout.connect(reload_sources)
        watcher.fileChanged.connect(lambda _: debounce.start())
        watcher.directoryChanged.connect(lambda _: debounce.start())
        watch_sources()
        connect_close(engine.rootObjects()[0])
        print("Watching QML sources", flush=True)

    def finish() -> None:
        if args.capture:
            args.capture.parent.mkdir(parents=True, exist_ok=True)
            window = engine.rootObjects()[0]
            image = window.screen().grabWindow(window.winId())
            if image.isNull() or not image.save(str(args.capture)):
                warnings.append("Screenshot capture failed")
        app.quit()

    if args.smoke or args.capture:
        QTimer.singleShot(700, finish)
    result = app.exec()
    for warning in warnings:
        print(warning, file=sys.stderr)
    return 1 if warnings else result


if __name__ == "__main__":
    raise SystemExit(main())
