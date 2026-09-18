import json
import sys
from collections import OrderedDict
from pathlib import Path

import numpy as np
from material_color_utilities import Hct, TonalPalette, prominent_colors_from_array
from PIL import Image, ImageOps
from PySide6.QtCore import QObject, QProcess, QTimer, QUrl


def extract_palette(source):
    url = QUrl(source)
    if not url.isLocalFile():
        raise ValueError("A local wallpaper file is required")
    with Image.open(url.toLocalFile()) as original:
        image = ImageOps.exif_transpose(original).convert("RGBA")
        image.thumbnail((128, 128))
        pixels = np.asarray(image, dtype=np.uint32).reshape(-1, 4)
    opaque = pixels[pixels[:, 3] >= 128]
    if not len(opaque):
        raise ValueError("Wallpaper has no visible pixels")
    packed = (255 << 24) | (opaque[:, 0] << 16) | (opaque[:, 1] << 8) | opaque[:, 2]
    spread = opaque[:, :3].max(axis=1) - opaque[:, :3].min(axis=1)
    neutral = float(spread.mean()) < 8
    if neutral:
        hue, chroma = 0, 0
    else:
        prominent = prominent_colors_from_array(packed)
        if not prominent:
            raise ValueError("No wallpaper colors found")
        seed = Hct(prominent[0])
        hue, chroma = seed.hue, min(18, seed.chroma)
    tones = TonalPalette(hue, chroma)
    return {name: tones.get(tone) for name, tone in {
        "paper": 94, "ink": 8, "muted": 70, "line": 38,
        "hover": 19, "stage": 84, "accent": 82,
    }.items()}


class PaletteBridge(QObject):
    def __init__(self, sampler, parent):
        super().__init__(parent)
        self.sampler = sampler
        self.cache = OrderedDict()
        self.active_source = ""
        self.process = QProcess(self)
        self.process.finished.connect(self.finished)
        self.process.errorOccurred.connect(self.failed)
        self.timeout = QTimer(self)
        self.timeout.setSingleShot(True)
        self.timeout.setInterval(10000)
        self.timeout.timeout.connect(self.expired)
        sampler.generationRequested.connect(self.request)
        sampler.destroyed.connect(self.stop)
        if sampler.property("extractionEnabled"):
            self.request(sampler.property("source").toString())

    def stop(self):
        self.timeout.stop()
        self.process.blockSignals(True)
        if self.process.state() != QProcess.ProcessState.NotRunning:
            self.process.kill()
            self.process.waitForFinished(1000)

    def request(self, source):
        self.pending_source = source
        if self.process.state() != QProcess.ProcessState.NotRunning:
            return
        self.start_pending()

    def start_pending(self):
        source = self.pending_source
        self.active_source = source
        if source in self.cache:
            self.sampler.acceptResult(source, self.cache[source], "Ready")
            return
        self.sampler.acceptResult(source, {}, "Generating wallpaper colors")
        self.process.start(sys.executable, [str(Path(__file__).resolve()), source])
        self.timeout.start()

    def finished(self, exit_code, _status):
        self.timeout.stop()
        palette = {}
        try:
            payload = json.loads(bytes(self.process.readAllStandardOutput()))
            if exit_code == 0:
                palette = payload["palette"]
        except (ValueError, KeyError):
            pass
        if palette:
            self.cache[self.active_source] = palette
            if len(self.cache) > 32:
                self.cache.popitem(last=False)
        self.sampler.acceptResult(self.active_source, palette, "Ready" if palette else "Wallpaper colors unavailable")
        if self.pending_source != self.active_source:
            self.start_pending()

    def failed(self, error):
        if error == QProcess.ProcessError.FailedToStart:
            self.timeout.stop()
            self.sampler.acceptResult(self.active_source, {}, "Palette helper unavailable")

    def expired(self):
        self.process.kill()


def attach_palette_backend(engine):
    for root in engine.rootObjects():
        sampler = root.findChild(QObject, "wallpaperPalette")
        if sampler is not None:
            return PaletteBridge(sampler, engine)
    return None


if __name__ == "__main__":
    try:
        print(json.dumps({"palette": extract_palette(sys.argv[1])}))
    except Exception as error:
        print(json.dumps({"palette": {}, "error": str(error)}))
        sys.exit(1)