// Qt Quick Test runner for the Simple UI. Provides the `globals` context property the app sets in MainRootWindow.
#include <QtQuickTest>
#include <QQmlEngine>
#include <QQmlContext>
#include <QQmlPropertyMap>

#include "../../src/SimplePinHash.h"

// The app's CustomPlugin PIN helpers (S12), for the mock corePlugin
class SimplePin : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
    Q_INVOKABLE QString hash  (const QString& pin) const { return SimplePinHash::hash(pin); }
    Q_INVOKABLE bool    check (const QString& pin, const QString& stored) const { return SimplePinHash::check(pin, stored); }
    Q_INVOKABLE bool    isHash(const QString& stored) const { return SimplePinHash::isHash(stored); }
};

class Setup : public QObject
{
    Q_OBJECT
public slots:
    void qmlEngineAvailable(QQmlEngine* engine)
    {
        auto* globals = new QQmlPropertyMap(engine);
        globals->insert(QStringLiteral("planMasterControllerFlyView"), QVariant());
        globals->insert(QStringLiteral("guidedControllerFlyView"), QVariant());    // tests set a double (S35 Go here)
        engine->rootContext()->setContextProperty(QStringLiteral("globals"), globals);
        engine->rootContext()->setContextProperty(QStringLiteral("simplePin"), new SimplePin(engine));
    }
};

QUICK_TEST_MAIN_WITH_SETUP(simple, Setup)

#include "main.moc"
