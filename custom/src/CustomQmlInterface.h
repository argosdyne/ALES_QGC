#pragma once

#include <QParallelAnimationGroup>
#include <QPropertyAnimation>
#include <QSoundEffect>
#include "QGCToolbox.h"
#include "ARManager.h"
#include "QmlObjectListModel.h"

class CustomPlugin;
class CustomQmlInterface;
class CodevRTCMManager;
class mDNSManager;
class LTEManager;
#define DEFAULT_REMOTE_PORT_UDP_QGC_SLAVE   14599   ///< Slave port

enum class GeoAwarenessErrorId {
    Unknown = 0,
    Inside,
    Near,
    NoData
};

class SystemMessage : public QObject
{
    Q_OBJECT
public:
    /** @enum SystemMessageType
     * @brief Type of system message.
     */
    typedef enum {
        Info,    ///< Information
        Error,   ///< Error
        Warning, ///< Warning
        Success, ///< Success
        None
    }SystemMessageType;
    Q_ENUMS(SystemMessageType)
    Q_PROPERTY(float opacity READ opacity WRITE setOpacity NOTIFY opacityChanged)
    Q_PROPERTY(float y READ y WRITE setY NOTIFY yChanged)
    Q_PROPERTY(QString context READ context CONSTANT)
    Q_PROPERTY(QString icon READ icon CONSTANT)
    Q_PROPERTY(QString color READ color CONSTANT)
    Q_PROPERTY(float width READ width CONSTANT)
    Q_PROPERTY(float height READ height CONSTANT)
    SystemMessage(CustomQmlInterface* parent = nullptr);

    QString context(void) const { return _context; }
    QString icon(void) const;
    QString color(void) const;
    float width(void) const { return _width; }
    float height(void) const { return _height; }
    float opacity(void) const { return _opacity; }
    float y(void) const { return _y; }

    void setOpacity(const float& opacity);
    void setContext(const QString& context);
    void setType(const SystemMessageType& type);
    void setY(const float& y);

    QPropertyAnimation* createYAnimation(QVariant from, QVariant to);

    //GeoAwareness --------------------------------------------------------------
    Q_PROPERTY(QString geoAwarenessContext READ geoAwarenessContext CONSTANT)
    QString geoAwarenessContext(void) const {return _geoAwarenessContext; }
    void setGeoAwarenessContext(const QString& context);
    Q_PROPERTY(float geoAwarenessWidth READ geoAwarenessWidth CONSTANT)
    Q_PROPERTY(float geoAwarenessHeight READ geoAwarenessHeight CONSTANT)
    Q_PROPERTY(float geoAwarenessOpacity READ geoAwarenessOpacity WRITE setGeoAwarenessOpacity NOTIFY geoAwarenessOpacityChanged)
    Q_PROPERTY(float geoAwarenessY READ geoAwarenessY WRITE setGeoAwarenessY NOTIFY geoAwarenessYChagned)
    float geoAwarenessWidth(void) const {return _geoAwarenessWidth; }
    float geoAwarenessHeight(void) const {return _geoAwarenessHeight; }
    float geoAwarenessOpacity(void) const {return _geoAwarenessOpacity; }
    float geoAwarenessY(void) const {return _geoAwarenessY; }
    void setGeoAwarenessOpacity(const float& opacity);
    void setGeoAwarenessY(const float& geoy);
    QPropertyAnimation* geoAwarenessCreateYAnimation(QVariant from, QVariant to);    
    void setGeoAwarenessType();
    void setGeoAwarenessErrorId(GeoAwarenessErrorId errorId) { _geoAwarenessErrorId = errorId; }
    GeoAwarenessErrorId geoAwarenessErrorId(void) const { return _geoAwarenessErrorId; }


public slots:
    void closeItstyle();
    void startCloseItstyle();

    //GeoAwareness ---
    void geoAwarenessCloseItstyle();
    void geoAwarnessStartCloseItstyle();

signals:
    void opacityChanged(const float& opacity);
    void yChanged(const float& y);

    //GeoAwareness ------
    void geoAwarenessOpacityChanged(const float& opacity);
    void geoAwarenessYChagned(const float& geoy);

private:
    QTimer _timer;
    QString _context;
    float _width;
    float _height;
    SystemMessageType _type;
    float _opacity;
    float _y;
    CustomQmlInterface* _customQmlInterface;
    QPropertyAnimation *_yAnimation;

    //GeoAwareness
    QString _geoAwarenessContext;
    float _geoAwarenessWidth;
    float _geoAwarenessHeight;
    float _geoAwarenessOpacity;
    float _geoAwarenessY;
    QPropertyAnimation *_geoAwarenessYAnimation;
    QTimer _geoAwarenessTimer;
    GeoAwarenessErrorId _geoAwarenessErrorId{GeoAwarenessErrorId::Unknown};

};

class CustomQmlInterface : public QGCTool
{
    friend class SystemMessage;
    Q_OBJECT
public:
    typedef enum {
        CUSTOM_FUNCTION_COACH_WAYPOINT,
        CUSTOM_FUNCTION_THERMAL_ZOOM,
        CUSTOM_FUNCTION_IR_SWITCH,
        CUSTOM_FUNCTION_GIMBAL_RESET,
        CUSTOM_FUNCTION_AIRCRAFT_RTL,
        CUSTOM_FUNCTION_START_MISSION,
        CUSTOM_FUNCTION_CAMERA_CAPTURE,
        CUSTOM_FUNCTION_CAMERA_TOGGLE_RECORD
    } CUSTOM_FUNCTION;
    Q_PROPERTY(ARManager* arManager READ arManager CONSTANT)
    Q_PROPERTY(CodevRTCMManager* codevRTCMManager READ codevRTCMManager CONSTANT)
    Q_PROPERTY(QmlObjectListModel* systemMessages READ systemMessages CONSTANT)
    Q_PROPERTY(LTEManager* lteManager READ lteManager CONSTANT)        
    Q_PROPERTY(float defaultFontPixelHeight MEMBER _defaultFontPixelHeight NOTIFY defaultFontPixelChanged)
    Q_PROPERTY(float defaultFontPixelWidth MEMBER _defaultFontPixelWidth NOTIFY defaultFontPixelChanged)

    CustomQmlInterface(QGCApplication* app, QGCToolbox* toolbox);
    ~CustomQmlInterface() override;

    ARManager* arManager()  { return _arManager; }
    CodevRTCMManager* codevRTCMManager() { return _codevRTCMManager; }
    QmlObjectListModel* systemMessages(void) { return &_systemMessages; }
    LTEManager* lteManager(void) { return _lteManager; }

    //GeoAwareness Messages
    Q_PROPERTY(QmlObjectListModel* geoAwarenessMessages READ geoAwarenessMessages CONSTANT)
    QmlObjectListModel* geoAwarenessMessages(void) {return &_geoAwarenessMessages; }

    Q_INVOKABLE void playActionSound();

    // Overrides from QGCTool
    void setToolbox(QGCToolbox* toolbox) override;
    static CustomQmlInterface* instance();
    static void setInstance(CustomQmlInterface*);

    explicit CustomQmlInterface(QObject* parent = nullptr);

signals:
    void coachWaypointTigger(bool start);
    void thermalZoomTigger(bool start);
    void irSwitchTigger(bool start);
    void gimbalResetTigger(bool start);
    void cameraCapture(bool start);
    void cameraToggleRecord(bool start);

    void defaultFontPixelChanged();    

public slots:
    /**
     * @brief Show messages to system prompt.
     * @param message context.
     * @param type type of system prompt.
     * @see ::SystemMessage::SystemMessageType
     */
    void showMessage(const QString& message, SystemMessage::SystemMessageType type = SystemMessage::Info);
    void handleCustomButtonFunction(int type, bool pressed);
    void handleAviatorButton(int type, bool pressed);
    void showMapUpdateDate();

    //GeoAwareness Message Window
    void geoAwarenessMessage(const QString& message);

private slots:
    void _slaveModeChanged(bool slaveMode);

private:
    void _refreshSystemMessageUI(bool from);
    QParallelAnimationGroup _group;
    QmlObjectListModel _systemMessages;
    QList<SystemMessage*> _normalSystemMessages;

    //GeoAwareness Message
    QmlObjectListModel _geoAwarenessMessages;
    QList<SystemMessage*> _geoAwarenessNormalSystemMessages;
    void _geoAwarenessRefreshSystemMessageUI(bool from);
    QParallelAnimationGroup _geoAwarenessGroup;

    CustomPlugin* _plugin{nullptr};
    ARManager* _arManager{nullptr};
    CodevRTCMManager* _codevRTCMManager{nullptr};    
    mDNSManager* _mDNSManager{nullptr};
    LTEManager* _lteManager{nullptr};

    QSoundEffect _actionSound;

    float _defaultFontPixelHeight{16.0f};
    float _defaultFontPixelWidth{10.0f};
    QString                 _cachePath;
    QString                 _cacheFile;
    QGCApplication*         _app;
    static CustomQmlInterface* _instance;
    QString errorMessage = "";
    QSet<QString> _shownMessages;    
};
