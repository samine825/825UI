import QtQuick
import ".."

// Гранёный фрейм — шестиугольник с выемками на серединах боковых
// сторон — тонкая обёртка InfexBox (выемки на обоих рёбрах).
// Границы элемента = видимому внешнему краю обводки c1: контур
// инсетнут на пол-линии.
//
// shadow: "both"    — нарост-тень снаружи + внутреннее кольцо
//         "outside" — только нарост снаружи (бывшая тонкая внешняя
//                     линия приведена к каноничному наросту)
//         "inside"  — только внутреннее кольцо
//         "none"    — без теней
//
// Дети — над фоном, клип по силуэту рамки, под обводкой и тенями
// (кольцо лежит на детях — бывшая shadowOverContent всегда).
// Унаследованные fillColor/strokeColor перекрываются биндингами, не
// redeclaration (тень собственности оторвала бы внутренности
// InfexBox от значений потребителя).
InfexBox {
    id: frame

    property string shadow: "both"

    // тени InfexBox рисуются c2; свойство оставлено потребителям
    property color shadowColor: Settings.c2

    sideInset: 0
    edgeLeft: "Notch"
    edgeRight: "Notch"

    // дефолт старого SFrame (у InfexBox fillColor — цвет заливки, c1)
    fillColor: Settings.c2

    backgroundColor: fillColor
    shadowOuter: shadow === "both" || shadow === "outside"
    shadowInner: shadow === "both" || shadow === "inside"
}
