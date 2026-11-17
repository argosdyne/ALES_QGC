// Qt Quick Test runner for the Simple UI. Provides the `globals` context property the app sets in MainRootWindow.
#include <QtQuickTest>
#include <QQmlEngine>
#include <QQmlContext>
#include <QQmlPropertyMap>


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
    }
};

QUICK_TEST_MAIN_WITH_SETUP(simple, Setup)

#include "main.moc"
