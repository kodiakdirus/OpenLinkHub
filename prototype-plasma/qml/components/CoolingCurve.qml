import QtQuick

Canvas {
    id: curve

    property color accentColor: "#66d7c5"
    property color gridColor: "#32414b"
    property real intensity: 0.7

    implicitWidth: 230
    implicitHeight: 72
    antialiasing: true

    onAccentColorChanged: requestPaint()
    onGridColorChanged: requestPaint()
    onIntensityChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const w = width
        const h = height

        ctx.strokeStyle = gridColor
        ctx.lineWidth = 1
        for (let i = 1; i < 4; ++i) {
            const y = Math.round(h * i / 4) + 0.5
            ctx.beginPath()
            ctx.moveTo(0, y)
            ctx.lineTo(w, y)
            ctx.stroke()
        }

        const points = [
            [0, h * 0.82],
            [w * 0.20, h * 0.82],
            [w * 0.42, h * (0.72 - intensity * 0.12)],
            [w * 0.66, h * (0.58 - intensity * 0.27)],
            [w * 0.83, h * (0.42 - intensity * 0.28)],
            [w, h * 0.12]
        ]

        ctx.strokeStyle = accentColor
        ctx.fillStyle = accentColor
        ctx.lineWidth = 2.5
        ctx.beginPath()
        points.forEach((point, index) => {
            if (index === 0) ctx.moveTo(point[0], point[1])
            else ctx.lineTo(point[0], point[1])
        })
        ctx.stroke()

        points.forEach(point => {
            ctx.beginPath()
            ctx.arc(point[0], point[1], 3.5, 0, Math.PI * 2)
            ctx.fill()
        })
    }
}
