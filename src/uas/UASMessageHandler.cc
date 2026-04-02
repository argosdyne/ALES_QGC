/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


/*!
 * @file
 *   @brief Message Handler
 *   @author Gus Grubba <gus@auterion.com>
 */

#include "QGCApplication.h"
#include "UASMessageHandler.h"
#include "MultiVehicleManager.h"
#include "Vehicle.h"
#include <QDateTime>
#include <QRegularExpression>

namespace {

static constexpr int kMaxStoredMessages              = 200;
static constexpr qint64 kDuplicateThrottleWindowMs   = 3000;
static constexpr qint64 kUiBurstWindowMs             = 2000;
static constexpr int kUiBurstThreshold               = 8;
static const QRegularExpression kHtmlTagExpression(QStringLiteral("<[^>]*>"));

QString throttleKeyForText(const QString& text)
{
    QString plainText = text;
    plainText.remove(kHtmlTagExpression);
    plainText = plainText.simplified().toLower();

    if (plainText.contains(QStringLiteral("radio failsafe"))) {
        return QStringLiteral("radio-failsafe");
    }
    if (plainText.contains(QStringLiteral("precland0")) || plainText.contains(QStringLiteral("precland1")) || plainText.contains(QStringLiteral("precland"))) {
        return QStringLiteral("precland-nactive");
    }
    if (plainText.contains(QStringLiteral("prearm: radio failsafe on"))) {
        return QStringLiteral("prearm-radio-failsafe");
    }

    return QString();
}

}

UASMessage::UASMessage(int componentid, int severity, QString text)
{
    _compId   = componentid;
    _severity = severity;
    _text     = text;
}

bool UASMessage::severityIsError() const
{
    switch (_severity) {
        case MAV_SEVERITY_EMERGENCY:
        case MAV_SEVERITY_ALERT:
        case MAV_SEVERITY_CRITICAL:
        case MAV_SEVERITY_ERROR:
            return true;
        default:
            return false;
    }
}

UASMessageHandler::UASMessageHandler(QGCApplication* app, QGCToolbox* toolbox)
    : QGCTool(app, toolbox)
    , _activeVehicle(nullptr)
    , _activeComponent(-1)
    , _multiComp(false)
    , _errorCount(0)
    , _errorCountTotal(0)
    , _warningCount(0)
    , _normalCount(0)
    , _showErrorsInToolbar(false)
    , _multiVehicleManager(nullptr)
{

}

UASMessageHandler::~UASMessageHandler()
{
    clearMessages();
}

void UASMessageHandler::setToolbox(QGCToolbox *toolbox)
{
   QGCTool::setToolbox(toolbox);

   _multiVehicleManager = _toolbox->multiVehicleManager();

   connect(_multiVehicleManager, &MultiVehicleManager::activeVehicleChanged, this, &UASMessageHandler::_activeVehicleChanged);
   emit textMessageReceived(nullptr);
   emit textMessageCountChanged(0);
}

void UASMessageHandler::clearMessages()
{
    _mutex.lock();
    while(_messages.count()) {
        delete _messages.last();
        _messages.pop_back();
    }
    _messageDisplayTimeMap.clear();
    _uiMessageBurstWindow.clear();
    _errorCount   = 0;
    _warningCount = 0;
    _normalCount  = 0;
    _mutex.unlock();
    emit textMessageCountChanged(0);
}

void UASMessageHandler::_activeVehicleChanged(Vehicle* vehicle)
{
    // If we were already attached to an autopilot, disconnect it.
    if (_activeVehicle) {
        disconnect(_activeVehicle, &Vehicle::textMessageReceived, this, &UASMessageHandler::handleTextMessage);
        _activeVehicle = nullptr;
        clearMessages();
        emit textMessageReceived(nullptr);
    }

    // And now if there's an autopilot to follow, set up the UI.
    if (vehicle) {
        // Connect to the new UAS.
        clearMessages();
        _activeVehicle = vehicle;
        connect(_activeVehicle, &Vehicle::textMessageReceived, this, &UASMessageHandler::handleTextMessage);
    }
}

void UASMessageHandler::handleTextMessage(int, int compId, int severity, QString text, QString description)
{
    // Hack to prevent calibration messages from cluttering things up
    if (_activeVehicle->px4Firmware() && text.startsWith(QStringLiteral("[cal] "))) {
        return;
    }

    text = text.replace("\n", "<br/>");
    // TODO: handle text + description separately in the UI
    if (!description.isEmpty()) {
        text += "<br/><small><small>" + description.replace("\n", "<br/>") + "</small></small>";
    }

    // Color the output depending on the message severity. We have 3 distinct cases:
    // 1: If we have an ERROR or worse, make it bigger, bolder, and highlight it red.
    // 2: If we have a warning or notice, just make it bold and color it orange.
    // 3: Otherwise color it the standard color, white.

    _mutex.lock();

    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (_shouldDropDuplicateMessage(severity, text, now)) {
        _mutex.unlock();
        return;
    }

    if (_activeComponent < 0) {
        _activeComponent = compId;
    }

    if (compId != _activeComponent) {
        _multiComp = true;
    }

    // So first determine the styling based on the severity.
    QString style;
    switch (severity)
    {
    case MAV_SEVERITY_EMERGENCY:
    case MAV_SEVERITY_ALERT:
    case MAV_SEVERITY_CRITICAL:
    case MAV_SEVERITY_ERROR:
        style = QString("<#E>");
        _errorCount++;
        _errorCountTotal++;
        break;
    case MAV_SEVERITY_NOTICE:
    case MAV_SEVERITY_WARNING:
        style = QString("<#I>");
        _warningCount++;
        break;
    default:
        style = QString("<#N>");
        _normalCount++;
        break;
    }

    // And determine the text for the severitie
    QString severityText;
    switch (severity)
    {
    case MAV_SEVERITY_EMERGENCY:
        severityText = tr(" EMERGENCY:");
        break;
    case MAV_SEVERITY_ALERT:
        severityText = tr(" ALERT:");
        break;
    case MAV_SEVERITY_CRITICAL:
        severityText = tr(" Critical:");
        break;
    case MAV_SEVERITY_ERROR:
        severityText = tr(" Error:");
        break;
    case MAV_SEVERITY_WARNING:
        severityText = tr(" Warning:");
        break;
    case MAV_SEVERITY_NOTICE:
        severityText = tr(" Notice:");
        break;
    case MAV_SEVERITY_INFO:
        severityText = tr(" Info:");
        break;
    case MAV_SEVERITY_DEBUG:
        severityText = tr(" Debug:");
        break;
    default:
        break;
    }

    // Finally preppend the properly-styled text with a timestamp.
    QString dateString = QDateTime::currentDateTime().toString("hh:mm:ss.zzz");
    UASMessage* message = new UASMessage(compId, severity, text);
    QString compString;
    if (_multiComp) {
        compString = QString(" COMP:%1").arg(compId);
    }
    message->_setFormatedText(QString("<font style=\"%1\">[%2%3]%4 %5</font><br/>").arg(style).arg(dateString).arg(compString).arg(severityText).arg(text));

    _messages.append(message);
    _trimMessages();
    int count = _messages.count();

    const bool suppressUiUpdate = _shouldSuppressUiUpdate(severity, now);
    _mutex.unlock();

    if (!suppressUiUpdate) {
        emit textMessageReceived(message);
    }

    emit textMessageCountChanged(count);

    if (!suppressUiUpdate && _showErrorsInToolbar && message->severityIsError()) {
        _app->showCriticalVehicleMessage(message->getText());
    }
}

bool UASMessageHandler::_shouldDropDuplicateMessage(int severity, const QString& text, qint64 now)
{
    Q_UNUSED(severity);

    const QString key = throttleKeyForText(text);
    if (key.isEmpty()) {
        return false;
    }

    const auto it = _messageDisplayTimeMap.constFind(key);
    if (it != _messageDisplayTimeMap.constEnd() && (now - it.value()) < kDuplicateThrottleWindowMs) {
        return true;
    }

    _messageDisplayTimeMap[key] = now;
    return false;
}

bool UASMessageHandler::_shouldSuppressUiUpdate(int severity, qint64 now)
{
    if (severity > MAV_SEVERITY_WARNING) {
        return false;
    }

    while (!_uiMessageBurstWindow.isEmpty() && (now - _uiMessageBurstWindow.head()) > kUiBurstWindowMs) {
        _uiMessageBurstWindow.dequeue();
    }

    _uiMessageBurstWindow.enqueue(now);
    return _uiMessageBurstWindow.count() > kUiBurstThreshold;
}

void UASMessageHandler::_trimMessages()
{
    while (_messages.count() > kMaxStoredMessages) {
        delete _messages.takeFirst();
    }
}

int UASMessageHandler::getErrorCountTotal() {
    _mutex.lock();
    int c = _errorCountTotal;
    _mutex.unlock();
    return c;
}

int UASMessageHandler::getErrorCount() {
    _mutex.lock();
    int c = _errorCount;
    _errorCount = 0;
    _mutex.unlock();
    return c;
}

int UASMessageHandler::getWarningCount() {
    _mutex.lock();
    int c = _warningCount;
    _warningCount = 0;
    _mutex.unlock();
    return c;
}

int UASMessageHandler::getNormalCount() {
    _mutex.lock();
    int c = _normalCount;
    _normalCount = 0;
    _mutex.unlock();
    return c;
}
