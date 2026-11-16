/****************************************************************************
 * AQGC Simple UI — admin PIN dialog in a modal popup, for "Change PIN" in Advanced › Settings › General.
 * The classic settings page is itself shown in a modal popup (tool drawer): a plain item in the window overlay
 * would get no touches, so the PIN dialog is put in its own popup on top.
 ****************************************************************************/
import QtQuick 2.12
import QtQuick.Controls 2.12
import "."

Item {
    id: root
    signal pinChanged()

    function open(purpose) { popup.open(); dlg.open(purpose) }

    Popup {
        id: popup
        parent: Overlay.overlay
        x: 0; y: 0
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        modal: true
        dim: false                       // the dialog dims the window itself
        padding: 0
        closePolicy: Popup.CloseOnEscape
        background: null
        onClosed: if (dlg.opened) dlg.close()

        SimplePinDialog {
            id: dlg
            anchors.fill: parent
            onOpenedChanged: if (!opened) popup.close()
            onPinChanged: root.pinChanged()
        }
    }
}
