from pathlib import Path

from PySide6.QtCore import QPointF, QRectF
from PySide6.QtGui import QColor, QImage, QPainter, QPen, QPolygonF


def main() -> None:
    destination = Path(__file__).resolve().parents[1] / "shell" / "Assets" / "Wallpapers"
    destination.mkdir(parents=True, exist_ok=True)
    paper = QColor("#efefeb")
    ink = QColor("#171819")
    middle = QColor("#c4c6bf")
    width, height = 2560, 1440
    for name in ("fold", "orbit", "steps"):
        image = QImage(width, height, QImage.Format.Format_RGB32)
        image.fill(paper)
        painter = QPainter(image)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setPen(QPen(middle, 1))
        for column in range(0, width, 80):
            painter.drawLine(column, 0, column, height)
        for row in range(0, height, 80):
            painter.drawLine(0, row, width, row)
        painter.setPen(QPen(ink, 2))
        if name == "fold":
            painter.setBrush(ink)
            painter.drawPolygon(QPolygonF([QPointF(720, 920), QPointF(1280, 360), QPointF(1840, 920)]))
            painter.setBrush(paper)
            painter.drawPolygon(QPolygonF([QPointF(720, 920), QPointF(1280, 720), QPointF(1840, 920)]))
        elif name == "orbit":
            for ring in range(9):
                inset = ring * 26
                painter.drawEllipse(QRectF(860 + inset, 300 + inset, 840 - inset * 2, 840 - inset * 2))
            painter.fillRect(1272, 220, 16, 1000, ink)
        else:
            for step in range(7):
                painter.fillRect(820 + step * 120, 1000 - step * 100, 120, 100 + step * 100, ink)
        painter.end()
        if not image.save(str(destination / f"{name}.png")):
            raise RuntimeError(f"Could not write {name} wallpaper")


if __name__ == "__main__":
    main()