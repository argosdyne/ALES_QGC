add_library(FactControls
    FactPanelController.cc
)

add_custom_target(FactControlsQml
	SOURCES
		FactPanelController.h
		AltitudeFactTextField.qml
		FactBitmask.qml
		FactCheckBox.qml
		FactComboBox.qml
		FactLabel.qml
		FactTextField.qml
		FactTextFieldSlider.qml
)

target_link_libraries(FactControls qgc)
