import QtQuick
import ".."

// Прямоугольник со срезанными углами — тонкая обёртка InfexBox
// (плоские рёбра). Границы элемента = видимому внешнему краю
// обводки c1 (контур инсетнут на пол-линии).
//
// shadow: "both"    — нарост-тень снаружи + внутреннее кольцо
//         "outside" — только нарост снаружи (бывшая тонкая внешняя
//                     линия приведена к каноничному наросту)
//         "inside"  — только внутреннее кольцо
//         "none"    — без теней
//
// Прозрачная заливка — бокса под контентом нет вовсе. Дети — над
// фоном, клип по силуэту, под обводкой и тенями. Унаследованные
// cornerCut/fillColor/strokeColor перекрываются биндингами (не
// redeclaration — тень собственности оторвала бы внутренности
// InfexBox от значений потребителя).
InfexBox {
    id: panel

    property string shadow: "none"
    property bool flatLeft: false
    property bool flatRight: false

    // тени InfexBox рисуются c2; свойство оставлено потребителям
    property color shadowColor: Settings.c2

    sideInset: 0
    edgeLeft: "Flat"
    edgeRight: "Flat"

    cornerCut: Settings.line * 2

    // дефолт старого SPanel
    fillColor: Settings.c2

    // прижатая к краю экрана сторона — без среза
    cornerCutLeft: flatLeft ? 0 : NaN
    cornerCutRight: flatRight ? 0 : NaN

    backgroundColor: fillColor
    shadowOuter: shadow === "both" || shadow === "outside"
    shadowInner: shadow === "both" || shadow === "inside"
}
