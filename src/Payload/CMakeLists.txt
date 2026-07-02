add_library(Payload
	PayloadController.cc
	PayloadController.h
	GremsyLynxPayloadController.cc
	GremsyLynxPayloadController.h
	NextVisionPayloadController.cc
	NextVisionPayloadController.h
)

target_link_libraries(Payload
	PUBLIC
		Qt5::Network
		qgc
)

target_include_directories(Payload
	PUBLIC
		${CMAKE_CURRENT_SOURCE_DIR}
)
