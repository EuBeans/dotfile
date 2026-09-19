import argparse
from datetime import datetime
import json
import math
from pathlib import Path
import shutil
import subprocess
import tempfile
import os


def pixel_region(region, view_size, image_size):
    if not all(math.isfinite(value) for value in (*region, *view_size, *image_size)):
        raise ValueError("Invalid selection coordinates")
    left, top, width, height = region
    view_width, view_height = view_size
    image_width, image_height = image_size
    if min(width, height, view_width, view_height, image_width, image_height) <= 0:
        raise ValueError("Select a non-empty region")
    right = min(image_width, math.ceil((left + width) * image_width / view_width))
    bottom = min(image_height, math.ceil((top + height) * image_height / view_height))
    left = max(0, math.floor(left * image_width / view_width))
    top = max(0, math.floor(top * image_height / view_height))
    if right <= left or bottom <= top:
        raise ValueError("Selection is outside the captured screen")
    return left, top, right - left, bottom - top


def capture(source, region, view_size, output_directory=None):
    source = Path(source).resolve(strict=True)
    dimensions = subprocess.run(["magick", "identify", "-format", "%w %h", str(source)],
                                capture_output=True, text=True, check=True, timeout=15)
    image_size = tuple(int(value) for value in dimensions.stdout.split())
    left, top, width, height = pixel_region(region, view_size, image_size)
    result = {"success": False, "path": "", "copied": False, "save_error": "", "clipboard_error": ""}
    with tempfile.TemporaryDirectory(prefix="quickshell-capture-") as directory:
        cropped = Path(directory) / "capture.png"
        subprocess.run(["magick", str(source), "-crop", f"{width}x{height}+{left}+{top}",
                        "+repage", str(cropped)], capture_output=True, check=True, timeout=15)
        if output_directory:
            saved = None
            try:
                destination = Path(output_directory).expanduser().resolve()
                destination.mkdir(parents=True, exist_ok=True)
                descriptor, filename = tempfile.mkstemp(prefix=datetime.now().strftime("screenshot-%Y-%m-%d_%H-%M-%S-"),
                                                       suffix=".png", dir=destination)
                os.close(descriptor)
                saved = Path(filename)
                shutil.copyfile(cropped, saved)
                result["path"] = str(saved)
            except OSError as error:
                if saved:
                    saved.unlink(missing_ok=True)
                result["save_error"] = str(error)
        try:
            with cropped.open("rb") as image, tempfile.TemporaryFile() as errors:
                try:
                    subprocess.run(["wl-copy", "--type", "image/png"], stdin=image,
                                   stdout=subprocess.DEVNULL, stderr=errors, check=True, timeout=15)
                except (OSError, subprocess.SubprocessError) as error:
                    errors.seek(0)
                    detail = errors.read().decode("utf-8", errors="replace").strip()
                    raise RuntimeError(detail or str(error)) from error
            result["copied"] = True
        except (OSError, RuntimeError) as error:
            result["clipboard_error"] = str(error)
    result["success"] = result["copied"] and not result["save_error"]
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source")
    parser.add_argument("--region", type=float, nargs=4, required=True)
    parser.add_argument("--view-size", type=float, nargs=2, required=True)
    parser.add_argument("--output-directory")
    arguments = parser.parse_args()
    try:
        result = capture(arguments.source, arguments.region, arguments.view_size, arguments.output_directory)
        print(json.dumps(result))
        return 0 if result["success"] else 1
    except Exception as error:
        print(json.dumps({"success": False, "error": str(error)}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())