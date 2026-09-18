import QtQuick

Canvas {
    id: sampler
    required property url source
    property var palette: null
    width: 32
    height: 32
    visible: false
    onSourceChanged: {
        palette = null;
        if (isImageLoaded(source)) requestPaint();
        else loadImage(source);
    }
    Component.onCompleted: loadImage(source)
    onImageLoaded: requestPaint()
    onPaint: {
        if (!isImageLoaded(source)) return;
        const context = getContext("2d");
        context.clearRect(0, 0, width, height);
        context.drawImage(source, 0, 0, width, height);
        const pixels = context.getImageData(0, 0, width, height).data;
        let red = 0, green = 0, blue = 0;
        let weight = 0;
        for (let offset = 0; offset < pixels.length; offset += 4) {
            const alpha = pixels[offset + 3] / 255;
            red += pixels[offset] * alpha;
            green += pixels[offset + 1] * alpha;
            blue += pixels[offset + 2] * alpha;
            weight += alpha;
        }
        if (!weight) { palette = null; return; }
        const count = weight * 255;
        red /= count; green /= count; blue /= count;
        function tint(base, amount) { return Qt.rgba(base + red * amount, base + green * amount, base + blue * amount, 1); }
        palette = {paper: tint(0.86, 0.12), ink: tint(0.055, 0.05), muted: tint(0.57, 0.15),
            line: tint(0.24, 0.13), hover: tint(0.12, 0.12), stage: tint(0.7, 0.16), accent: tint(0.62, 0.36)};
    }
}