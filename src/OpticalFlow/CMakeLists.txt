add_library(OpticalFlow
	OpticalFlowController.cc
)

target_link_libraries(OpticalFlow
	PRIVATE
		qgc
	PUBLIC
		Qt5::Core
		Qt5::Qml
)

target_include_directories(OpticalFlow PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
