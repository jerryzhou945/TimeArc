import QtQuick

// 记忆窗口氛围层（薄基底）。
// 历史上这里有一处居中柔光，但「记忆湖」光场已上移为 Shell 窗口级（蓝黑深度坡 + 左上 aqua /
// 右上 violet 角落辅光对）并由 CardCarousel 的中央列「上照湖光」承担中段升起的光。
// 那处居中 GlowCircle 与二者重复，且每个 GlowCircle 都是一层 MultiEffect 模糊 FBO——为守 §8
// 模糊层预算（实时高斯模糊层 ≤3），此处不再叠第三处大柔光，仅留透明基底让 Shell 背景透出。
Item {
    id: ambient

    property MemoryLakeStyle style
    property url appImage

    clip: true
}
