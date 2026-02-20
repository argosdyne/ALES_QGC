import QtQuick 2.7
import QtQuick.Controls 2.0
import QtQuick.Layouts 1.1

Page {
    id: registerPage

    signal pinRegistered()

    property int pinLength: 8
    property string errorMessage: ""
    property bool showError: false
    property string messageColor: "#ff5c5c"  // Default red for errors

       background: Rectangle {
           color: "#000000"
       }

       function pinValue(rowRepeater) {
           var value = ""
           for (var i = 0; i < pinLength; i++)
               value += rowRepeater.itemAt(i).text
           return value
       }

       function validatePIN() {
           var p1 = pinValue(enterRepeater)
           var p2 = pinValue(confirmRepeater)

           // Kiểm tra độ dài PIN
           if (p1.length < 6 || p2.length < 6) {
               errorMessage = "Please enter 6 - 8 digits pin"
               messageColor = "#ff5c5c"
               showError = true
               return false
           }

           // Kiểm tra độ mạnh PIN bằng C++
           var strengthError = securityManager.validatePINStrength(p1)
           if (strengthError) {
               errorMessage = strengthError
               messageColor = "#ff5c5c"
               showError = true
               return false
           }

           // Kiểm tra PIN match
           if (p1 !== p2) {
               errorMessage = "PINs do not match"
               messageColor = "#ff5c5c"
               showError = true
               return false
           }

           showError = false
           return true
       }

       Column {
           anchors.centerIn: parent
           spacing: 30
           width: parent.width * 0.85

           Rectangle {
               width: 70
               height: 70
               radius: 35
               anchors.horizontalCenter: parent.horizontalCenter
               gradient: Gradient {
                   GradientStop { position: 0; color: "#4f7cff" }
                   GradientStop { position: 1; color: "#7a5cff" }
               }

               Text {
                   anchors.centerIn: parent
                   text: "🛡"
                   font.pixelSize: 28
               }
           }

           Text {
               text: "Set Your Admin PIN"
               color: "white"
               font.pixelSize: 35
               font.bold: true
               horizontalAlignment: Text.AlignHCenter
               anchors.horizontalCenter: parent.horizontalCenter
           }

           Text {
               text: "Create a secure 6–8 digit PIN to protect your profile"
               color: "#a0aec0"
               font.pixelSize: 18
               horizontalAlignment: Text.AlignHCenter
               anchors.horizontalCenter: parent.horizontalCenter
           }

           // ===== ENTER PIN =====
           Column {
               id: pinEnter
               spacing: 10
               anchors.horizontalCenter: parent.horizontalCenter

               Text {
                   text: "Enter PIN"
                   color: "#8ea0b8"
                   anchors.horizontalCenter: parent.horizontalCenter
               }

               Row {
                   spacing: 12
                   anchors.horizontalCenter: parent.horizontalCenter

                   Repeater {
                       id: enterRepeater
                       model: pinLength

                       PinBox {
                           index: model.index

                           onNextRequested: {
                               if (index < pinLength - 1)
                                   enterRepeater.itemAt(index + 1).forceActiveFocus()
                               else
                                   confirmRepeater.itemAt(0).forceActiveFocus()
                           }

                           onPrevRequested: {
                               if (index > 0)
                                   enterRepeater.itemAt(index - 1).forceActiveFocus()
                           }

                           onTextChanged: {
                               // Real-time PIN strength check via C++
                               var currentPin = pinValue(enterRepeater)
                               var strengthError = currentPin.length >= 6 ? securityManager.validatePINStrength(currentPin) : ""
                               if (strengthError) {
                                   errorMessage = strengthError
                                   messageColor = "#ff5c5c"
                                   showError = true
                               } else if (currentPin.length >= 6) {
                                   errorMessage = "✓ PIN strength: Good"
                                   messageColor = "#48bb78"
                                   showError = true
                               } else {
                                   showError = false
                               }
                           }
                       }
                   }
               }
           }

           // ===== CONFIRM PIN =====
           Column {
               id: pinConfirm
               spacing: 10
               anchors.horizontalCenter: parent.horizontalCenter

               Text {
                   text: "Confirm PIN"
                   color: "#8ea0b8"
                   anchors.horizontalCenter: parent.horizontalCenter
               }

               Row {
                   spacing: 12
                   anchors.horizontalCenter: parent.horizontalCenter

                   Repeater {
                       id: confirmRepeater
                       model: pinLength

                       PinBox {
                           index: model.index

                           onNextRequested: {
                               if (index < pinLength - 1)
                                   confirmRepeater.itemAt(index + 1).forceActiveFocus()
                           }

                           onPrevRequested: {
                               if (index > 0)
                                   confirmRepeater.itemAt(index - 1).forceActiveFocus()
                               else
                                   enterRepeater.itemAt(pinLength - 1).forceActiveFocus()
                           }
                       }
                   }
               }
           }

           Text {
               text: errorMessage
               visible: showError
               color: messageColor
               font.bold: true
               anchors.horizontalCenter: parent.horizontalCenter
               font.pixelSize: 18
           }

           Button {
               text: "Continue"
               // enabled: isValid()
               width: pinConfirm.width
               anchors.horizontalCenter: parent.horizontalCenter
               height: 70

               onClicked: {
                   if (validatePIN()) {
                       // set the PIN securely via SecurityManager exposed to QML
                       var p = pinValue(enterRepeater)
                       var ok = false
                       try {
                           ok = securityManager.setPin(p)
                       } catch(e) {
                           ok = false
                       }
                       if (ok) {
                           registerPage.pinRegistered()
                       } else {
                           errorMessage = "Failed to store PIN"
                           showError = true
                       }
                   }
               }

               background: Rectangle {
                   radius: 8
                   gradient: Gradient {
                       GradientStop { position: 0; color: enabled ? "#4f7cff" : "#2d3748" }
                       GradientStop { position: 1; color: enabled ? "#7a5cff" : "#2d3748" }
                   }
               }

               contentItem: Text {
                   text: parent.text
                   color: "white"
                   font.pixelSize: 30
                   horizontalAlignment: Text.AlignHCenter
                   verticalAlignment: Text.AlignVCenter
                   anchors.fill: parent
                   font.bold: true
               }
           }

           Text {
               text: "Your PIN is encrypted and stored securely"
               color: "#64748b"
               anchors.horizontalCenter: parent.horizontalCenter
               font.pixelSize: 18
           }
       }

       Component.onCompleted: {
           enterRepeater.itemAt(0).forceActiveFocus()
       }
}
