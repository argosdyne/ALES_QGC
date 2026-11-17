/****************************************************************************
 * AQGC — data on this device, for Simple UI S65 Security & privacy / S67 Delete my data (Figma 118:39104,
 * 118:39319; CE RED 3.3(e), EN 18031-2 deletion, 2026-11-17). Exposed as corePlugin.privacyData.
 *
 * Categories (keys used by QML): "logs" (telemetry + downloaded logs + crash files), "media" (videos and photos),
 * "missions" (saved plans), "accounts" (passwords, keys, tokens in SecureStore + the MAVLink signing key),
 * "settings" (all app settings, applied at the next start). The map cache is handled in QML (mapEngineManager).
 * Data on the drone is never touched. Folder scans and deletions run in a worker thread.
 ****************************************************************************/
#pragma once

#include <QFutureWatcher>
#include <QObject>
#include <QStringList>
#include <QVariantMap>

class LinkSecurity;

class PrivacyData : public QObject
{
    Q_OBJECT
public:
    explicit PrivacyData(LinkSecurity* linkSecurity, QObject* parent = nullptr);

    Q_PROPERTY(bool         busy        READ busy        NOTIFY busyChanged)
    /// key → { files: int, bytes: double, plans: int (missions only) }
    Q_PROPERTY(QVariantMap  sizes       READ sizes       NOTIFY sizesChanged)
    /// stored accounts and keys, plain names only: "NTRIP", "Altitude Angel", "Radio", "Map tokens", "OTA", "Link key"
    Q_PROPERTY(QStringList  accounts    READ accounts    NOTIFY accountsChanged)
    /// "" (checking) | "verified" | "unsigned" | "invalid" | "android" (the system checks the APK at install)
    Q_PROPERTY(QString      signature   READ signature   NOTIFY signatureChanged)
    Q_PROPERTY(QString      signer      READ signer      NOTIFY signatureChanged)
    /// newest first
    Q_PROPERTY(QStringList  securityLog READ securityLog NOTIFY securityLogChanged)
    /// last delete: "" | "deleted" | "restart" (app settings are cleared at the next start)
    Q_PROPERTY(QString      result      READ result      NOTIFY resultChanged)
    Q_PROPERTY(bool         canOpenFolder READ canOpenFolder CONSTANT)

    Q_INVOKABLE void refresh            ();
    Q_INVOKABLE void deleteData         (const QStringList& keys);
    Q_INVOKABLE void openFolder         ();
    Q_INVOKABLE void reloadSecurityLog  ();
    Q_INVOKABLE void clearResult        ();
    /// one line in the security log (e.g. tuning changed in flight, S76); never pass a secret
    Q_INVOKABLE void logEvent           (const QString& source, const QString& text);

    bool        busy        () const { return _busy; }
    QVariantMap sizes       () const { return _sizes; }
    QStringList accounts    () const { return _accounts; }
    QString     signature   () const { return _signature; }
    QString     signer      () const { return _signer; }
    QStringList securityLog () const { return _securityLog; }
    QString     result      () const { return _result; }
    bool        canOpenFolder() const;

signals:
    void busyChanged        ();
    void sizesChanged       ();
    void accountsChanged    ();
    void signatureChanged   ();
    void securityLogChanged ();
    void resultChanged      ();

private:
    QVariantMap _folders        () const;   ///< key → QStringList of folders
    void        _updateAccounts ();
    void        _checkSignature ();
    void        _setBusy        (bool busy);

    LinkSecurity*               _linkSecurity = nullptr;
    QFutureWatcher<QVariantMap> _scanWatcher;
    QFutureWatcher<void>        _deleteWatcher;
    QFutureWatcher<QStringList> _signatureWatcher;
    bool        _busy = false;
    QVariantMap _sizes;
    QStringList _accounts;
    QString     _signature;
    QString     _signer;
    QStringList _securityLog;
    QString     _result;
    QString     _pendingResult;
};
