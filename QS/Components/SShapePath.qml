import QtQuick
import QtQuick.Shapes
import ".."
ShapePath {
    // лимит митера выше дефолта (2): у острых углов шестигранников
    // (внутренний угол ~52°) соотношение длины митера к ширине штриха
    // 1/sin(26°) ≈ 2.29 — с дефолтом Qt срезал угол bevel'ом, и углы
    // выглядели обрезанными; у октагонов (135°, ≈1.08) дефолта хватало
    miterLimit: 4

    Behavior on fillColor {
        ColorAnimation { duration: Settings.animBase }
    }
    Behavior on strokeColor {
        ColorAnimation { duration: Settings.animBase }
    }
}
