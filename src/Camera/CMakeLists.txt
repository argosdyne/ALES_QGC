
add_library(Camera
	MavlinkCameraControl.cc
	MavlinkCameraControl.h
	QGCCameraIO.cc
	QGCCameraIO.h
	QGCCameraManager.cc
	QGCCameraManager.h
	SimulatedCameraControl.cc
	SimulatedCameraControl.h
	VehicleCameraControl.cc
	VehicleCameraControl.h
)

target_link_libraries(Camera
	PUBLIC
		qgc
)

target_include_directories(Camera PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

