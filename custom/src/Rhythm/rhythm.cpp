// rhythm.cpp
#include "rhythm.h"
#include <QDebug>
#include <QDateTime>
#include <MultiVehicleManager.h>  // Include for MultiVehicleManager (if needed)

Rhythm::Rhythm(QObject *parent)
    : QObject(parent)
    , m_udpSocket(nullptr)
    , m_cameraPort(0)
    , m_connected(false)
    , m_lastHeartbeatTime(0)
    , m_systemId(255)          // Default system ID for GCS
    , m_componentId(0)         // Default component ID for GCS
    , m_targetSystemId(1)      // Default target system ID
    , m_targetComponentId(100) // Default camera component ID (MAV_COMP_ID_CAMERA)
    , m_targetGComponentId(154)
    , m_hasCameraInfo(false)
{
    // Set up heartbeat timer (1Hz)
    m_heartbeatTimer.setInterval(1000);
    connect(&m_heartbeatTimer, &QTimer::timeout, this, &Rhythm::sendHeartbeat);

    // Set up connection timeout checker
    m_connectionTimer.setInterval(2000);
    connect(&m_connectionTimer, &QTimer::timeout, this, &Rhythm::checkConnectionTimeout);
}

Rhythm::~Rhythm()
{
    closeConnection();
}

bool Rhythm::setup(const QString& cameraIp, int port)
{
    // Close any existing connection
    closeConnection();

    // Set camera address and port
    m_cameraAddress = QHostAddress(cameraIp);
    m_cameraPort = port;

    // Create new UDP socket
    m_udpSocket = new QUdpSocket(this);

    // Connect signals for incoming data
    connect(m_udpSocket, &QUdpSocket::readyRead, this, &Rhythm::processPendingDatagrams);

    // Bind to any address on the specified port
    if (!m_udpSocket->bind(QHostAddress::AnyIPv4, port)) {
        emit cameraError(QString("Failed to bind UDP socket to port %1: %2")
                             .arg(port)
                             .arg(m_udpSocket->errorString()));
        closeConnection();
        return false;
    }

    // Start sending heartbeats
    m_heartbeatTimer.start();

    // Start checking connection
    m_connectionTimer.start();

    //qDebug() << "Camera connection setup initiated to" << m_cameraAddress.toString() << ":" << m_cameraPort;
    return true;
}

bool Rhythm::checkConnection()
{
    return m_connected;
}

void Rhythm::closeConnection()
{
    // Stop timers
    m_heartbeatTimer.stop();
    m_connectionTimer.stop();

    if (m_udpSocket) {
        m_udpSocket->close();
        delete m_udpSocket;
        m_udpSocket = nullptr;
    }

    if (m_connected) {
        m_connected = false;
        emit connectionStatusChanged();
    }
}

void Rhythm::sendHeartbeat()
{
    if (!m_udpSocket) {
        return;
    }

    // Create MAVLink heartbeat message
    mavlink_message_t msg;
    mavlink_msg_heartbeat_pack(m_systemId, m_componentId, &msg,
                               MAV_TYPE_GCS, // Type (Ground Control Station)
                               MAV_AUTOPILOT_INVALID, // Autopilot type
                               0, // Base mode
                               0, // Custom mode
                               MAV_STATE_ACTIVE); // System state

    // Send the message
    sendMavlinkMessage(msg);
}

void Rhythm::checkConnectionTimeout()
{
    qint64 currentTime = QDateTime::currentMSecsSinceEpoch();

    // If we haven't received a heartbeat for 5 seconds, consider disconnected
    bool isConnected = (m_lastHeartbeatTime > 0 && (currentTime - m_lastHeartbeatTime) < 5000);

    if (m_connected != isConnected) {
        m_connected = isConnected;
        emit connectionStatusChanged();

        if (m_connected) {
            qDebug() << "Camera connected (heartbeat detected)";
        } else {
            qDebug() << "Camera disconnected (heartbeat timeout)";
        }
    }
}

void Rhythm::sendMavlinkMessage(const mavlink_message_t& message)
{
    if (!m_udpSocket) {
        return;
    }

    // Create buffer for message
    uint8_t buffer[MAVLINK_MAX_PACKET_LEN];

    // Copy message to buffer
    int len = mavlink_msg_to_send_buffer(buffer, &message);

    // Create QByteArray from buffer
    QByteArray data((const char*)buffer, len);

    // Send datagram
    qint64 bytesSent = m_udpSocket->writeDatagram(data, m_cameraAddress, m_cameraPort);

    if (bytesSent != len) {
        emit cameraError(QString("Failed to send MAVLink message: %1").arg(m_udpSocket->errorString()));
    }
}

void Rhythm::processPendingDatagrams()
{
    while (m_udpSocket && m_udpSocket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(int(m_udpSocket->pendingDatagramSize()));

        QHostAddress sender;
        quint16 senderPort;

        m_udpSocket->readDatagram(datagram.data(), datagram.size(), &sender, &senderPort);

        // Parse all MAVLink messages in the datagram
        mavlink_message_t message;
        mavlink_status_t status;

        for (int i = 0; i < datagram.size(); i++) {
            if (mavlink_parse_char(MAVLINK_COMM_0, (uint8_t)datagram[i], &message, &status)) {
                // We have a complete MAVLink message

                // Update target system and component IDs if needed
                if (m_targetSystemId != message.sysid) {
                    m_targetSystemId = message.sysid;
                    qDebug() << "Updated target system ID to" << m_targetSystemId;
                }

                // Handle message based on its ID
                switch (message.msgid) {
                case MAVLINK_MSG_ID_HEARTBEAT:
                    handleHeartbeat(message);
                    break;

                case MAVLINK_MSG_ID_CAMERA_IMAGE_CAPTURED:
                    handleImageCaptured(message);
                    break;

                case MAVLINK_MSG_ID_PARAM_EXT_VALUE:
                    handleMavlinkMessage(message);  // Handle received parameter
                    break;

                case MAVLINK_MSG_ID_PARAM_EXT_ACK:
                    processMavlinkResponse(message);  // Handle acknowledgment of set parameter
                    break;

                case MAVLINK_MSG_ID_CAMERA_TRACKING_IMAGE_STATUS:
                    handleMavlinkMessage(message);  // Pass to your handler for tracking status
                    // qDebug() << "Received tracking status message";
                    break;

                default:
                    // Handle other message types as needed
                    // qDebug() << "Received MAVLink message ID:" << message.msgid;
                    break;
                }
            }
        }
    }
}
void Rhythm::handleHeartbeat(const mavlink_message_t& message)
{
    // Update the last heartbeat time
    m_lastHeartbeatTime = QDateTime::currentMSecsSinceEpoch();

    // Parse heartbeat message
    mavlink_heartbeat_t heartbeat;
    mavlink_msg_heartbeat_decode(&message, &heartbeat);

    // If we receive a heartbeat from a camera component, update the component ID
    if (message.compid == MAV_COMP_ID_CAMERA && m_targetComponentId != message.compid) {
        m_targetComponentId = message.compid;
        qDebug() << "Updated target component ID to" << m_targetComponentId << "(Camera)";
    }

    // Update connection status if needed
    if (!m_connected) {
        m_connected = true;
        emit connectionStatusChanged();
        qDebug() << "Camera connected (heartbeat received from"
                 << "sysid:" << message.sysid
                 << "compid:" << message.compid << ")";
    }

    emit heartbeatReceived();
}
bool Rhythm::takePicture()
{
    if (!m_connected) {
        emit cameraError("Cannot take picture: Camera not connected");
        return false;
    }

    qDebug() << "Requesting image capture from camera...";

    // Create MAVLink message for IMAGE_START_CAPTURE
    mavlink_message_t msg;

    // MAV_CMD_IMAGE_START_CAPTURE (2000) command parameters:
    // param1: Reserved (set to 0)
    // param2: Interval between two consecutive pictures (in seconds) - 0 = single image
    // param3: Total number of images to capture - 1 = single image
    // param4: Photo index (use NaN if unknown as per documentation)
    // param5: Capture sequence (unused) - 0
    // param6: Reserved (all 0)
    // param7: Reserved (all 0)

    // Create a NaN value for param4 as specified in the documentation
    union {
        float f;
        uint32_t i;
    } nan_value;
    nan_value.i = 0x7FC00000; // IEEE 754 NaN value

    mavlink_msg_command_long_pack(m_systemId, m_componentId, &msg,
                                  m_targetSystemId, m_targetComponentId,
                                  MAV_CMD_IMAGE_START_CAPTURE, // 2000
                                  0, // Confirmation
                                  0, // param1: Reserved
                                  0, // param2: Interval (0 for single image)
                                  1, // param3: Number of images (1)
                                  nan_value.f, // param4: Photo index (NaN if unknown)
                                  0, // param5: Reserved
                                  0, // param6: Reserved
                                  0  // param7: Reserved
                                  );

    // Send the message
    sendMavlinkMessage(msg);

    qDebug() << "Image capture command sent to camera with parameters:";
    qDebug() << "  Target System ID:" << m_targetSystemId;
    qDebug() << "  Target Component ID:" << m_targetComponentId;

    return true;
}
void Rhythm::handleImageCaptured(const mavlink_message_t& message)
{
    mavlink_camera_image_captured_t img;
    mavlink_msg_camera_image_captured_decode(&message, &img);

    // Get the image filename from the URL field
    QString imageFileName = QString((const char*)img.file_url);

    qDebug() << "Image captured!";
    qDebug() << "  Image ID:" << img.image_index;
    qDebug() << "  File:" << imageFileName;
    qDebug() << "  Position:" << img.lat << img.lon << img.alt;
    qDebug() << "  Timestamp:" << img.time_utc;

    emit imageCaptured(img.image_index, imageFileName);
}
bool Rhythm::controlGimbal(float pitch, float yaw, float roll)
{
    if (!m_connected) {
        emit cameraError("Cannot control gimbal: Camera not connected");
        return false;
    }

    qDebug() << "Sending gimbal control command...";

    // Create MAVLink message for DO_MOUNT_CONTROL
    mavlink_message_t msg;

    // MAV_CMD_DO_MOUNT_CONTROL (205) command parameters:
    // param1: Pitch (degrees) or pitch rate, depending on mount mode
    // param2: Roll (degrees) or roll rate, depending on mount mode
    // param3: Yaw (degrees) or yaw rate, depending on mount mode
    // param4: Altitude (meters) - not used
    // param5: Latitude - not used
    // param6: Longitude - not used
    // param7: MAV_MOUNT_MODE enum value

    mavlink_msg_command_long_pack(m_systemId, m_componentId, &msg,
                                  m_targetSystemId, m_targetGComponentId,
                                  MAV_CMD_DO_MOUNT_CONTROL, // 205
                                  0, // Confirmation
                                  pitch, // param1: Pitch in degrees
                                  roll,  // param2: Roll in degrees
                                  yaw,   // param3: Yaw in degrees
                                  0,     // param4: Reserved (altitude)
                                  0,     // param5: Reserved (latitude)
                                  0,     // param6: Reserved (longitude)
                                  MAV_MOUNT_MODE_MAVLINK_TARGETING  // param7: Mount mode
                                  );

    // Send the message
    sendMavlinkMessage(msg);

    qDebug() << "Gimbal control command sent with parameters:";
    qDebug() << "  Pitch:" << pitch << "degrees";
    qDebug() << "  Roll:" << roll << "degrees";
    qDebug() << "  Yaw:" << yaw << "degrees";

    return true;
}
bool Rhythm::startVideo()
{
    if (!m_connected) {
        emit cameraError("Cannot start video: Camera not connected");
        return false;
    }

    qDebug() << "Starting video recording...";

    // Create MAVLink message for VIDEO_START_CAPTURE
    mavlink_message_t msg;

    // MAV_CMD_VIDEO_START_CAPTURE (2500) command parameters:
    // param1: Stream ID (0 for all streams)
    // param2: Status frequency - number of status messages to be sent per second
    // param3-7: Reserved (all 0)

    mavlink_msg_command_long_pack(m_systemId, m_componentId, &msg,
                                  m_targetSystemId, m_targetComponentId,
                                  MAV_CMD_VIDEO_START_CAPTURE, // 2500
                                  0, // Confirmation
                                  0, // param1: Stream ID (0 for all streams)
                                  5, // param2: Status frequency (5 Hz)
                                  0, // param3: Reserved
                                  0, // param4: Reserved
                                  0, // param5: Reserved
                                  0, // param6: Reserved
                                  0  // param7: Reserved
                                  );

    // Send the message
    sendMavlinkMessage(msg);

    // Update recording state
    m_isRecording = true;

    qDebug() << "Video start command sent to camera with parameters:";
    qDebug() << "  Target System ID:" << m_targetSystemId;
    qDebug() << "  Target Component ID:" << m_targetComponentId;

    return true;
}
bool Rhythm::stopVideo()
{
    if (!m_connected) {
        emit cameraError("Cannot stop video: Camera not connected");
        return false;
    }

    qDebug() << "Stopping video recording...";

    // Create MAVLink message for VIDEO_STOP_CAPTURE
    mavlink_message_t msg;

    // MAV_CMD_VIDEO_STOP_CAPTURE (2501) command parameters:
    // param1: Stream ID (0 for all streams)
    // param2-7: Reserved (all 0)

    mavlink_msg_command_long_pack(m_systemId, m_componentId, &msg,
                                  m_targetSystemId, m_targetComponentId,
                                  MAV_CMD_VIDEO_STOP_CAPTURE, // 2501
                                  0, // Confirmation
                                  0, // param1: Stream ID (0 for all streams)
                                  0, // param2: Reserved
                                  0, // param3: Reserved
                                  0, // param4: Reserved
                                  0, // param5: Reserved
                                  0, // param6: Reserved
                                  0  // param7: Reserved
                                  );

    // Send the message
    sendMavlinkMessage(msg);

    // Update recording state
    m_isRecording = false;

    qDebug() << "Video stop command sent to camera with parameters:";
    qDebug() << "  Target System ID:" << m_targetSystemId;
    qDebug() << "  Target Component ID:" << m_targetComponentId;

    return true;
}
bool Rhythm::setCameraMode(int mode)
{
    if (!m_connected) {
        emit cameraError("Cannot change mode: Camera not connected");
        return false;
    }

    qDebug() << "Changing camera mode to" << (mode == 0 ? "Photo" : "Video");

    // Create MAVLink message for SET_CAMERA_MODE
    mavlink_message_t msg;

    // MAV_CMD_SET_CAMERA_MODE (530) command parameters:
    // param1: Camera mode (0 = Photo, 1 = Video)
    // param2-7: Reserved (all 0)

    mavlink_msg_command_long_pack(m_systemId, m_componentId, &msg,
                                  m_targetSystemId, m_targetComponentId,
                                  MAV_CMD_SET_CAMERA_MODE, // 530
                                  0, // Confirmation
                                  mode, // param1: 0 = Photo, 1 = Video
                                  0, 0, 0, 0, 0, 0 // Reserved parameters
                                  );

    // Send the message
    sendMavlinkMessage(msg);

    qDebug() << "Camera mode change command sent to camera with parameters:";
    qDebug() << "  Target System ID:" << m_targetSystemId;
    qDebug() << "  Target Component ID:" << m_targetComponentId;
    qDebug() << "  Mode:" << mode;

    return true;
}

void Rhythm::requestParameter(const QString &paramId) {
    if (!m_connected) {
        emit cameraError("Cannot request parameter: Camera not connected");
        return;
    }

    mavlink_message_t msg;

    // Create the PARAM_EXT_REQUEST_READ message
    mavlink_msg_param_ext_request_read_pack(
        m_systemId, m_componentId, &msg,
        m_targetSystemId, m_targetComponentId,
        paramId.toUtf8().data(), -1 // Use -1 for param_index to request by name
        );

    sendMavlinkMessage(msg);

    qDebug() << "Requested parameter: " << paramId;
}
void Rhythm::requestAllParameters() {  // Ensure it's part of Rhythm class
    mavlink_message_t msg;
    mavlink_msg_param_ext_request_list_pack(
        m_systemId, m_componentId, &msg,
        m_targetSystemId, m_targetComponentId
        );
    sendMavlinkMessage(msg);

    qDebug() << "Sent PARAM_EXT_REQUEST_LIST to request all parameters.";
}

void Rhythm::setParameter(const QString &paramId, const QString &paramValue, int paramType) {
    qDebug() << "Setting parameter:" << paramId << "to value:" << paramValue << "of type:" << paramType;

    uint8_t type = static_cast<uint8_t>(paramType);

    // Ensure we are using the correct custom type (11) for custom parameters
    if (paramType == 11) {
        type = MAV_PARAM_EXT_TYPE_CUSTOM;  // Custom type is 11
    }

    mavlink_message_t msg;
    char paramIdBuf[16] = {0};  // Ensure 16-byte limit
    char paramValueBuf[128] = {0};  // Ensure 128-byte limit

    #ifdef _WIN32
    strncpy_s(paramIdBuf, sizeof(paramIdBuf), paramId.toUtf8().data(), _TRUNCATE);
    strncpy_s(paramValueBuf, sizeof(paramValueBuf), paramValue.toUtf8().data(), _TRUNCATE);
    #else
    strncpy(paramIdBuf, paramId.toUtf8().data(), sizeof(paramIdBuf) - 1);
    paramIdBuf[sizeof(paramIdBuf) - 1] = '\0';
    #endif


    qDebug() << "Sending MAVLink SET request with ID:" << paramIdBuf << "Value:" << paramValueBuf;

    mavlink_msg_param_ext_set_pack(
        m_systemId, m_componentId, &msg,
        m_targetSystemId, m_targetComponentId,
        paramIdBuf,
        paramValueBuf,
        type
        );

    sendMavlinkMessage(msg);
    qDebug() << "Setting parameter: " << paramId << " to value: " << paramValue << " of type: " << type;
}

void Rhythm::processMavlinkResponse(const mavlink_message_t &msg) {
    qDebug() << "Received MAVLink message ID:" << msg.msgid;

    if (msg.msgid == MAVLINK_MSG_ID_PARAM_EXT_ACK) {
        mavlink_param_ext_ack_t ack;
        mavlink_msg_param_ext_ack_decode(&msg, &ack);

        QString paramId = QString::fromUtf8(ack.param_id).trimmed();
        QString paramValue = QString::fromUtf8(ack.param_value).trimmed();
        int ackResult = ack.param_result;  // 0 = Accepted, 1 = Failed, 2 = Unsupported, etc.

        bool success = (ackResult == PARAM_ACK_ACCEPTED);

        qDebug() << "PARAM_EXT_ACK received: " << paramId << " = " << paramValue
                 << " Success:" << success << " Ack Result:" << ackResult;

        if (!success) {
            if (ackResult == PARAM_ACK_FAILED) {
                qDebug() << "Error: Setting parameter failed.";
            } else if (ackResult == PARAM_ACK_IN_PROGRESS) {
                qDebug() << "Warning: Parameter setting is in progress.";
            } else if (ackResult == PARAM_ACK_VALUE_UNSUPPORTED) {
                qDebug() << "Error: Parameter is unsupported.";
            }
        }

        emit parameterSetAckReceived(paramId, paramValue, success);
    }
}

// Modified handleMavlinkMessage method to handle binary detection data
void Rhythm::handleMavlinkMessage(const mavlink_message_t &msg) {
    if (msg.msgid == MAVLINK_MSG_ID_PARAM_EXT_VALUE) {
        mavlink_param_ext_value_t param;
        mavlink_msg_param_ext_value_decode(&msg, &param);

        QString paramId = QString::fromUtf8(param.param_id).trimmed();

        // Special handling for DETECT_OBJECTS parameter
        if (paramId == "DETECT_OBJECTS") {
            // qDebug() << "ID: " << paramId;

            // Get raw binary data
            const uint8_t* rawData = reinterpret_cast<const uint8_t*>(param.param_value);
            // Add debugging code here
            // qDebug() << "Raw data first bytes:"; // 1
            for (int i = 0; i < std::min(20, static_cast<int>(MAVLINK_MSG_PARAM_EXT_VALUE_FIELD_PARAM_VALUE_LEN)); i++) {
                // qDebug() << QString("Byte %1: 0x%2").arg(i).arg(QString::number(rawData[i], 16).rightJustified(2, '0')); //2
            }

            // use fixed value instead of strlen
            size_t dataLength = MAVLINK_MSG_PARAM_EXT_VALUE_FIELD_PARAM_VALUE_LEN;

            // check if all zeros values:
            bool allZeros = true;
            for(size_t i =0; i<6; i++){
                if (rawData[i] != 0){
                    allZeros =false;
                    break;
                }
            }
            if (dataLength == 0 || allZeros) {
                qDebug() << "Value: " << "No detection data (empty)";
                return;
            }

            // Parse the detection data
            DetectContent detections = parseDetectionData(rawData, dataLength);

            // Display the detection results
            if (detections.total > 0) {
                // qDebug() << "Detected" << detections.objects.size() << "objects:"; //3

                // Clear previous detection objects
                // m_detectionObjects.clear();

                // Format as JSON for easier viewing
                QJsonArray objectsArray;

                for (const auto& obj : detections.objects) {

                    // filter out invalid objects, all zeros or unreasonable values
                    if (obj.x ==0 && obj.y ==0 && obj.width ==0 && obj.height ==0 && obj.score ==0){
                        continue;   // skip empty objects
                    }

                    // Check for unreasonable coordinate values (you may need to adjust these thresholds)
                    if (obj.x / 10000.0f > 1.0f || obj.y / 10000.0f > 1.0f ||
                        obj.width / 10000.0f > 1.0f || obj.height / 10000.0f > 1.0f) {
                        qDebug() << "Skipping object with unreasonable coordinates";
                        continue;
                    }

                    QJsonObject objJson;
                    objJson["x"] = obj.x / 10000.0f;
                    objJson["y"] = obj.y / 10000.0f;
                    objJson["width"] = obj.width / 10000.0f;
                    objJson["height"] = obj.height / 10000.0f;
                    objJson["score"] = obj.score / 100.0f;
                    objJson["type"] = obj.type;
                    objectsArray.append(objJson);

                    // qDebug() << "  Object - X:" << obj.x / 10000.0f
                    //          << "Y:" << obj.y / 10000.0f
                    //          << "Width:" << obj.width / 10000.0f
                    //          << "Height:" << obj.height / 10000.0f
                    //          << "Score:" << obj.score / 100.0f
                    //          << "Type:" << obj.type;                   // 4


                    // // Create a map for each detection that QML can use
                    // QVariantMap detection;
                    // detection["x"] = obj.x / 10000.0f;
                    // detection["y"] = obj.y / 10000.0f;
                    // detection["width"] = obj.width / 10000.0f;
                    // detection["height"] = obj.height / 10000.0f;
                    // detection["score"] = obj.score / 100.0f;
                    // detection["type"] = obj.type;

                    // m_detectionObjects.append(detection);
                }

                QJsonObject result;
                result["Detected_Objects"] = objectsArray;
                QJsonDocument doc(result);
                QString jsonString = doc.toJson(QJsonDocument::Compact);

                // Emit signal with the detection results
                // qDebug() << " Emitting detectionResultsReceived signal:" << jsonString;

                emit detectionResultsReceived(jsonString);


            } else {
                qDebug() << "No objects detected in this frame";
            }
        }
        // Regular parameter handling for other parameters
        else {
            QString paramValue = QString::fromUtf8(param.param_value).trimmed();

            qDebug() << "ID: " << paramId;
            qDebug() << "Value: " << paramValue;
            qDebug() << "Type: " << param.param_type;
            qDebug() << "Index: " << param.param_index;

            // Process specific parameters
            if (paramId == "SMART_SELECT" || paramId == "TRACK_ALGORITHM") {
                if (paramValue == "Yolov8" || paramValue == "Yolov7" || paramValue == "Yolov11" ||
                    paramValue == "Nano" || paramValue == "SiamRPN") {
                    // Handle valid algorithm
                    emit parameterReceived(paramId, paramValue);
                } else {
                    qDebug() << "Unknown algorithm: " << paramValue;
                }
            }
            else if (paramId == "YAW_SMOOTH" || paramId == "DETECT_PLUGINS"){
                emit parameterReceived(paramId, paramValue);
            }
        }
    }
    // Handle camera tracking status messages
    // if (msg.msgid == MAVLINK_MSG_ID_CAMERA_TRACKING_IMAGE_STATUS) {
    //     // qDebug() << "Received MAVLink message ID:" << msg.msgid; // 1-T
    //     mavlink_camera_tracking_image_status_t status;
    //     mavlink_msg_camera_tracking_image_status_decode(&msg, &status);

    //     // Update tracking state
    //     bool wasTracking = m_isTracking;
    //     m_isTracking = (status.tracking_status == CAMERA_TRACKING_STATUS_FLAGS_ACTIVE);

    //     // Log tracking status changes
    //     if (m_isTracking != wasTracking) {
    //         qDebug() << "Tracking status changed to:" << (m_isTracking ? "ACTIVE" : "INACTIVE");
    //         emit trackingStateChanged();
    //     }

    //     // Create tracking data
    //     QVariantMap trackingData;
    //     trackingData["tracking_status"] = status.tracking_status;
    //     trackingData["tracking_mode"] = status.tracking_mode;
    //     trackingData["target_data"] = status.target_data;

    //     // Check if target data is in status message
    //     bool targetDataInStatus = (status.target_data & CAMERA_TRACKING_TARGET_DATA_IN_STATUS);

    //     // Log target data information
    //     // qDebug() << "Target data flags:" << status.target_data
    //     //          << "(In status:" << targetDataInStatus << ")"; //T-3

    //     // Only process coordinate data if it's included in the status
    //     if (targetDataInStatus) {
    //         // Handle mode-specific data
    //         if (status.tracking_mode == CAMERA_TRACKING_MODE_POINT) {
    //             trackingData["point_x"] = status.point_x;
    //             trackingData["point_y"] = status.point_y;
    //             trackingData["radius"] = status.radius;

    //             // qDebug() << "Tracking point - X:" << status.point_x
    //             //          << "Y:" << status.point_y
    //             //          << "Radius:" << status.radius;
    //         }
    //         else if (status.tracking_mode == CAMERA_TRACKING_MODE_RECTANGLE) {
    //             trackingData["rec_top_x"] = status.rec_top_x;
    //             trackingData["rec_top_y"] = status.rec_top_y;
    //             trackingData["rec_bottom_x"] = status.rec_bottom_x;
    //             trackingData["rec_bottom_y"] = status.rec_bottom_y;

    //             // qDebug() << "Tracking rectangle - TopLeft:" << status.rec_top_x << "," << status.rec_top_y
    //             //          << "BottomRight:" << status.rec_bottom_x << "," << status.rec_bottom_y;   //
    //         }
    //     } else {
    //         qDebug() << "Target data not included in status message";

    //         // Indicate where target data can be found
    //         if (status.target_data & CAMERA_TRACKING_TARGET_DATA_EMBEDDED) {
    //             qDebug() << "Target data is embedded in image data";
    //         }
    //         if (status.target_data & CAMERA_TRACKING_TARGET_DATA_RENDERED) {
    //             qDebug() << "Target data is rendered in image";
    //         }
    //     }

    //     // Update tracking data and notify
    //     m_trackingData = trackingData;
    //     emit trackingDataChanged();
    // }

    // Handle camera tracking status messages
    // Handle camera tracking status messages
    if (msg.msgid == MAVLINK_MSG_ID_CAMERA_TRACKING_IMAGE_STATUS) {
        mavlink_camera_tracking_image_status_t status;
        mavlink_msg_camera_tracking_image_status_decode(&msg, &status);

        // Update tracking state
        bool wasTracking = m_isTracking;
        m_isTracking = (status.tracking_status == CAMERA_TRACKING_STATUS_FLAGS_ACTIVE);

        // Log tracking status changes
        if (m_isTracking != wasTracking) {
            qDebug() << "Tracking status changed to:" << (m_isTracking ? "ACTIVE" : "INACTIVE");
            emit trackingStateChanged();
        }

        // Prepare JSON objects
        QJsonObject result;
        QJsonArray trackingArray;
        QJsonObject trackingObj;

        // Add basic tracking information
        trackingObj["tracking_status"] = status.tracking_status;
        trackingObj["tracking_mode"] = status.tracking_mode;
        trackingObj["target_data"] = status.target_data;

        // Check target data flags
        // bool targetDataInStatus = (status.target_data & CAMERA_TRACKING_TARGET_DATA_IN_STATUS);
        bool targetDataEmbedded = (status.target_data & CAMERA_TRACKING_TARGET_DATA_EMBEDDED);
        bool targetDataRendered = (status.target_data & CAMERA_TRACKING_TARGET_DATA_RENDERED);

        // Add information about target data location
        trackingObj["target_data_embedded"] = targetDataEmbedded;
        trackingObj["target_data_rendered"] = targetDataRendered;

        // // Debug logging for target data
        // qDebug() << "Target Data - In Status:" << targetDataInStatus
        //          << "Embedded:" << targetDataEmbedded
        //          << "Rendered:" << targetDataRendered;

        // Always try to add coordinate information
        if (status.tracking_mode == CAMERA_TRACKING_MODE_POINT) {
            // Point tracking mode
            trackingObj["point_x"] = status.point_x;
            trackingObj["point_y"] = status.point_y;
            trackingObj["radius"] = status.radius;

            // qDebug() << "Tracking point - X:" << status.point_x
            //          << "Y:" << status.point_y
            //          << "Radius:" << status.radius;
        }
        else if (status.tracking_mode == CAMERA_TRACKING_MODE_RECTANGLE) {
            // Rectangle tracking mode
            trackingObj["rec_top_x"] = status.rec_top_x;
            trackingObj["rec_top_y"] = status.rec_top_y;
            trackingObj["rec_bottom_x"] = status.rec_bottom_x;
            trackingObj["rec_bottom_y"] = status.rec_bottom_y;

            // qDebug() << "Tracking rectangle - TopLeft:" << status.rec_top_x << "," << status.rec_top_y
            //          << "BottomRight:" << status.rec_bottom_x << "," << status.rec_bottom_y;
        }

        // Add to tracking array and result
        trackingArray.append(trackingObj);
        result["Tracking_Objects"] = trackingArray;

        // Convert to JSON string
        QJsonDocument doc(result);
        QString jsonString = doc.toJson(QJsonDocument::Compact);

        // Emit signals
        emit trackingResultsReceived(jsonString);

        // Update internal tracking data
        m_trackingData.clear();
        for (auto it = trackingObj.begin(); it != trackingObj.end(); ++it) {
            m_trackingData[it.key()] = it.value().toVariant();
        }
        emit trackingDataChanged();
    }

}

DetectContent Rhythm::parseDetectionData(const uint8_t* data, size_t length) {
    DetectContent result;
    size_t offset = 0;

    if (length < 6) {
        qDebug() << "Warning: Not enough data for detection header";
        return result;
    }

    // Parse header using manual byte ordering (little-endian)
    auto readUint16 = [&data, &offset]() -> uint16_t {
        uint16_t value = data[offset] | (data[offset + 1] << 8);
        offset += 2;
        return value;
    };

    // Read header values
    result.index = readUint16();
    result.size = readUint16();
    result.total = readUint16();

    // qDebug() << "Detection data header - Index:" << result.index
    //          << "Size:" << result.size
    //          << "Total:" << result.total;     // 8

    // Each object is 12 bytes (6 uint16_t fields × 2 bytes)
    const size_t obj_size = 12;

    // Calculate expected total size
    // size_t expected_size = 6 + (result.total * obj_size); //6
    // qDebug() << "Expected data size:" << expected_size << ", Actual data size:" << length; // 7

    // Parse objects
    for (size_t i = 0; i < result.total && offset + obj_size <= length; ++i) {
        DetectedObject obj;

        // Read object data (all uint16_t) - store directly without conversion
        obj.x = readUint16();
        obj.y = readUint16();
        obj.width = readUint16();
        obj.height = readUint16();
        obj.score = readUint16();
        obj.type = readUint16();

        result.objects.append(obj);
    }
    return result;
}

void Rhythm::startDetection(const QString &detection_algo) {
    std::string param_to_set = "SMART_SELECT";
    std::string detection_model = detection_algo.toStdString();

    mavlink_message_t msg;
    char param_id[16] = {0};
    char param_value[128] = {0};

    // strncpy_s(param_id, sizeof(param_id), param_to_set.c_str(), _TRUNCATE);
    // strncpy_s(param_value, sizeof(param_value), detection_model.c_str(), _TRUNCATE);

#ifdef _WIN32
    strncpy_s(param_id, sizeof(param_id), param_to_set.c_str(), _TRUNCATE);
    strncpy_s(param_value, sizeof(param_value), detection_model.c_str(), _TRUNCATE);
#else
    strncpy(param_id, param_to_set.c_str(), sizeof(param_id) - 1);
    param_id[sizeof(param_id) - 1] = '\0';

    strncpy(param_value, detection_model.c_str(), sizeof(param_value) - 1);
    param_value[sizeof(param_value) - 1] = '\0';
#endif


    mavlink_msg_param_ext_set_pack(
        m_systemId, m_componentId, &msg,
        m_targetSystemId, m_targetComponentId,
        param_id,
        param_value,
        MAV_PARAM_EXT_TYPE_CUSTOM
        );

    sendMavlinkMessage(msg);
    qDebug() << "Setting detection algorithm to " << detection_algo;
}
void Rhythm::getDetectionStatus() {
    std::string param_to_get = "SMART_SELECT"; // The parameter ID for getting the detection status

    mavlink_message_t msg;
    char param_id[16] = {0};
    // strncpy_s(param_id, sizeof(param_id), param_to_get.c_str(), _TRUNCATE);
#ifdef _WIN32
    strncpy_s(param_id, sizeof(param_id), param_to_get.c_str(), _TRUNCATE);
#else
    strncpy(param_id, param_to_get.c_str(), sizeof(param_id) - 1);
    param_id[sizeof(param_id) - 1] = '\0';
#endif

    mavlink_msg_param_ext_request_read_pack(
        m_systemId, m_componentId, &msg,
        m_targetSystemId, m_targetComponentId,
        param_id,
        -1 // Use -1 for param_index to request by name
        );

    sendMavlinkMessage(msg);
    qDebug() << "Getting detection algorithm status for parameter " << QString::fromStdString(param_to_get);
}

void Rhythm::startTracking(const QString& track_algo) {
    std::string param_to_set = "TRACK_ALGORITHM"; // Parameter ID for setting tracking algorithm
    std::string track_model = track_algo.toStdString(); // For example, "TrackModel1", "TrackModel2"

    // Set the parameter for the tracking algorithm
    mavlink_message_t msg;
    char param_id[16] = {0};
    char param_value[128] = {0};

    // strncpy_s(param_id, sizeof(param_id), param_to_set.c_str(), _TRUNCATE);
    // strncpy_s(param_value, sizeof(param_value), track_model.c_str(), _TRUNCATE);

#ifdef _WIN32
    strncpy_s(param_id, sizeof(param_id), param_to_set.c_str(), _TRUNCATE);
    strncpy_s(param_value, sizeof(param_value), track_model.c_str(), _TRUNCATE);
#else
    strncpy(param_id, param_to_set.c_str(), sizeof(param_id) - 1);
    param_id[sizeof(param_id) - 1] = '\0';

    strncpy(param_value, track_model.c_str(), sizeof(param_value) - 1);
    param_value[sizeof(param_value) - 1] = '\0';
#endif


    mavlink_msg_param_ext_set_pack(
        m_systemId, m_componentId, &msg,
        m_targetSystemId, m_targetComponentId,
        param_id,
        param_value,
        MAV_PARAM_EXT_TYPE_CUSTOM
        );

    sendMavlinkMessage(msg);
    qDebug() << "Setting tracking algorithm to " << QString::fromStdString(track_model);
}

void Rhythm::startDetectionAndTracking(const QString& detection_algo, const QString& track_algo) {
    // Set Detection Algorithm
    startDetection(detection_algo); // Already handles setting the detection algorithm
    QThread::sleep(1);  // Add a small delay to ensure the first parameter is acknowledged (if needed)

    // Set Tracking Algorithm
    startTracking(track_algo); // Add this function to start the tracking algorithm
}

// Track a point in the image (normalized coordinates 0-1)
bool Rhythm::trackPoint(float x, float y, float radius) {
    mavlink_message_t msg;

    // Pack the COMMAND_LONG message for tracking a point
    mavlink_msg_command_long_pack(
        m_systemId,                // Your system ID
        m_componentId,             // Your component ID
        &msg,                      // The message to pack into
        m_targetSystemId,          // Target system (camera system ID)
        m_targetComponentId,       // Target component (camera component ID)
        MAV_CMD_CAMERA_TRACK_POINT,// Command ID for point tracking
        0,                         // Confirmation (0 for first transmission)
        x,                         // param1: Point x (normalized 0-1) from left to right
        y,                         // param2: Point y (normalized 0-1) from top to bottom
        radius,                    // param3: Radius of the point (normalized 0-1)
        0, 0, 0, 0);               // param4-7: Not used

    // Send the message
    sendMavlinkMessage(msg);
    // qDebug() << "Starting point tracking at x:" << x << "y:" << y << "radius:" << radius;
    // Update tracking state
    m_isTracking = true;
    emit trackingStateChanged();
    return true;
}

// Stop tracking
bool Rhythm::stopTracking() {
    mavlink_message_t msg;

    // Pack the COMMAND_LONG message to stop tracking
    mavlink_msg_command_long_pack(
        m_systemId,                // Your system ID
        m_componentId,             // Your component ID
        &msg,                      // The message to pack into
        m_targetSystemId,          // Target system (camera system ID)
        m_targetComponentId,       // Target component (camera component ID)
        MAV_CMD_CAMERA_STOP_TRACKING, // Command ID for stopping tracking
        0,                         // Confirmation (0 for first transmission)
        0, 0, 0, 0, 0, 0, 0);      // params: Not used

    // Send the message
    sendMavlinkMessage(msg);
    qDebug() << "Stopping tracking";
    // Update tracking state
    m_isTracking = false;
    emit trackingStateChanged();
    return true;
}


bool Rhythm::zoomRangeLevel(float zoomLevel) {
    mavlink_message_t msg;

    mavlink_msg_command_long_pack(
        m_systemId,
        m_componentId,
        &msg,
        m_targetSystemId,
        m_targetComponentId,
        MAV_CMD_SET_CAMERA_ZOOM,
        0,               // confirmation
        2,               // param1 = ZOOM_TYPE_RANGE
        zoomLevel,       // param2 = exact zoom multiplier (e.g., 5.0 = 5x zoom)
        0, 0, 0, 0, 0
        );

    sendMavlinkMessage(msg);
    qDebug() << "Zoom RANGE Command Sent - Zoom Level:" << zoomLevel;
    return true;
}

// // Set Video Resolution
// void Rhythm::setVideoResolution(int resolution) {
//     mavlink_message_t msg;

//     // Validate resolution values
//     if (resolution != 20 && resolution != 30 && resolution != 40) {
//         qDebug() << "Invalid resolution. Must be 20, 30, or 40.";
//         return;
//     }

//     // Prepare parameter ID
//     const char* base_id = "EO_VIDEO_QUALITY";

//     // Use extended parameter set to ensure correct transmission
//     mavlink_msg_param_ext_set_pack(
//         m_systemId,
//         m_componentId,
//         &msg,
//         m_targetSystemId,
//         m_targetComponentId,
//         base_id,
//         QByteArray::number(resolution).constData(),
//         MAV_PARAM_EXT_TYPE_INT32
//         );

//     // Send the message
//     sendMavlinkMessage(msg);

//     // Detailed debugging
//     qDebug() << "Video Resolution Setting:";
//     qDebug() << "  Param ID:" << base_id;
//     qDebug() << "  Resolution Value:" << resolution;

//     // Request to verify
//     requestParameter("EO_VIDEO_QUALITY");
// }

void Rhythm::setVideoResolution(int resolution) {
    // Validate resolution values
    if (resolution != 20 && resolution != 30 && resolution != 40) {
        qDebug() << "Invalid resolution. Must be 20, 30, or 40.";
        return;
    }

    mavlink_message_t msg;

    // Prepare parameter ID with special character
    char param_id[17] = "EO_VIDEO_QUALITY";
    param_id[15] = '\x14';  // Add special character

    // Prepare parameter value
    char param_value[128] = {0};
    param_value[0] = '\x14';  // Special first character
    snprintf(param_value + 1, sizeof(param_value) - 1, "%d", resolution);

    // Use extended parameter set
    mavlink_msg_param_ext_set_pack(
        m_systemId,
        m_componentId,
        &msg,
        m_targetSystemId,
        m_targetComponentId,
        param_id,
        param_value,
        MAV_PARAM_EXT_TYPE_INT32
        );

    // Send the message
    sendMavlinkMessage(msg);

    // Detailed debugging
    qDebug() << "Video Resolution Setting:";
    qDebug() << "  Param ID:" << param_id;
    qDebug() << "  Param ID Hex:" << QByteArray(param_id, 16).toHex();
    qDebug() << "  Param Value:" << param_value;
    qDebug() << "  Param Value Hex:" << QByteArray(param_value, 128).toHex();
    qDebug() << "  Resolution Value:" << resolution;

    // Request to verify
    requestParameter("EO_VIDEO_QUALITY");
}


// Set Video Bitrate
void Rhythm::setVideoBitrate(float bitrate) {
    mavlink_message_t msg;

    // Prepare parameter ID with special character
    char param_id[16] = "EO_BITRATE";
    param_id[11] = '\x14';  // Add special character

    // Convert bitrate to string
    char param_value[128] = {0};
    param_value[0] = '\x14';  // Special first character
    snprintf(param_value + 1, sizeof(param_value) - 1, "%.1f", bitrate);

    // Validate bitrate values
    if (bitrate < 1.0f || bitrate > 4.0f) {
        qDebug() << "Invalid bitrate. Must be between 1.0 and 4.0 Mbps.";
        return;
    }

    // Prepare parameter ID
    const char* base_id = "EO_BITRATE";

    // Use extended parameter set for float
    mavlink_msg_param_ext_set_pack(
        m_systemId,
        m_componentId,
        &msg,
        m_targetSystemId,
        m_targetComponentId,
        base_id,
        param_value,
        MAV_PARAM_EXT_TYPE_REAL32
        );

    // Send the message
    sendMavlinkMessage(msg);

    // Detailed debugging
    qDebug() << "Video Bitrate Setting:";
    qDebug() << "  Param ID:" << base_id;
    qDebug() << "  Param ID Hex:" << QByteArray(param_id, 16).toHex();
    qDebug() << "  Param Value:" << param_value;
    qDebug() << "  Param Value Hex:" << QByteArray(param_value, 128).toHex();
    qDebug() << "  Bitrate Value:" << bitrate;

    // Request to verify
    requestParameter("EO_BITRATE");
}



