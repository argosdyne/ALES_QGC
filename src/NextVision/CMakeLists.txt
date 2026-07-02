add_library(NextVision
	NextVisionController.cc
	NextVisionController.h
)

target_link_libraries(NextVision
	PUBLIC
		Qt5::Network
		qgc
)

target_include_directories(NextVision
	PUBLIC
		${CMAKE_CURRENT_SOURCE_DIR}
)
