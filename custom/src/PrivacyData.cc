/****************************************************************************
 * AQGC — data on this device (S65 / S67), see PrivacyData.h
 ****************************************************************************/

#include "PrivacyData.h"

#include "AppSettings.h"
#include "FlyViewSettings.h"
#include "LinkSecurity.h"
#include "QGCApplication.h"
#include "SecureStore.h"
#include "SecurityLog.h"
#include "SettingsManager.h"

#include <QCoreApplication>
#include <QDesktopServices>
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QSettings>
#include <QUrl>
#include <QtConcurrent>

#ifdef Q_OS_WIN
#include <windows.h>
#include <softpub.h>
#include <wincrypt.h>
#include <wintrust.h>
#endif

namespace {
    QVariantMap scanFolders(const QVariantMap& folders)
    {
        QVariantMap result;
        for (auto it = folders.constBegin(); it != folders.constEnd(); ++it) {
            int files = 0, plans = 0;
            double bytes = 0;
            for (const QString& dir : it.value().toStringList()) {
                if (dir.isEmpty() || !QFileInfo(dir).isDir()) {
                    continue;
                }
                QDirIterator iter(dir, QDir::Files | QDir::Hidden | QDir::NoSymLinks, QDirIterator::Subdirectories);
                while (iter.hasNext()) {
                    iter.next();
                    files++;
                    bytes += static_cast<double>(iter.fileInfo().size());
                    if (iter.fileInfo().suffix().compare(QStringLiteral("plan"), Qt::CaseInsensitive) == 0) {
                        plans++;
                    }
                }
            }
            QVariantMap entry;
            entry[QStringLiteral("files")] = files;
            entry[QStringLiteral("bytes")] = bytes;
            entry[QStringLiteral("plans")] = plans;
            result[it.key()] = entry;
        }
        return result;
    }

    /// delete the files in each folder (and its sub-folders); the folders themselves stay
    void deleteFolders(const QStringList& dirs)
    {
        for (const QString& dir : dirs) {
            if (dir.isEmpty() || !QFileInfo(dir).isDir()) {
                continue;
            }
            QDir d(dir);
            for (const QFileInfo& fi : d.entryInfoList(QDir::Files | QDir::Hidden | QDir::NoSymLinks)) {
                QFile::remove(fi.absoluteFilePath());
            }
            for (const QFileInfo& fi : d.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot | QDir::NoSymLinks)) {
                QDir(fi.absoluteFilePath()).removeRecursively();
            }
        }
    }

    /// {state, signer} of this executable
    QStringList checkSignature()
    {
#ifdef Q_OS_WIN
        const std::wstring file = QDir::toNativeSeparators(QCoreApplication::applicationFilePath()).toStdWString();
        WINTRUST_FILE_INFO fileInfo = {};
        fileInfo.cbStruct = sizeof(fileInfo);
        fileInfo.pcwszFilePath = file.c_str();
        WINTRUST_DATA data = {};
        data.cbStruct = sizeof(data);
        data.dwUIChoice = WTD_UI_NONE;
        data.fdwRevocationChecks = WTD_REVOKE_NONE;
        data.dwUnionChoice = WTD_CHOICE_FILE;
        data.pFile = &fileInfo;
        data.dwStateAction = WTD_STATEACTION_VERIFY;
        data.dwProvFlags = WTD_CACHE_ONLY_URL_RETRIEVAL;
        GUID action = WINTRUST_ACTION_GENERIC_VERIFY_V2;
        const LONG status = WinVerifyTrust(static_cast<HWND>(INVALID_HANDLE_VALUE), &action, &data);
        data.dwStateAction = WTD_STATEACTION_CLOSE;
        WinVerifyTrust(static_cast<HWND>(INVALID_HANDLE_VALUE), &action, &data);

        QString state = status == ERROR_SUCCESS ? QStringLiteral("verified")
                      : (status == TRUST_E_NOSIGNATURE || status == TRUST_E_SUBJECT_FORM_UNKNOWN || status == TRUST_E_PROVIDER_UNKNOWN)
                        ? QStringLiteral("unsigned") : QStringLiteral("invalid");
        QString signer;
        if (status == ERROR_SUCCESS) {
            HCERTSTORE store = nullptr;
            HCRYPTMSG msg = nullptr;
            if (CryptQueryObject(CERT_QUERY_OBJECT_FILE, file.c_str(), CERT_QUERY_CONTENT_FLAG_PKCS7_SIGNED_EMBED,
                                 CERT_QUERY_FORMAT_FLAG_BINARY, 0, nullptr, nullptr, nullptr, &store, &msg, nullptr)) {
                DWORD size = 0;
                if (CryptMsgGetParam(msg, CMSG_SIGNER_INFO_PARAM, 0, nullptr, &size) && size > 0) {
                    QByteArray buf(static_cast<int>(size), 0);
                    auto* info = reinterpret_cast<PCMSG_SIGNER_INFO>(buf.data());
                    if (CryptMsgGetParam(msg, CMSG_SIGNER_INFO_PARAM, 0, info, &size)) {
                        CERT_INFO certInfo = {};
                        certInfo.Issuer = info->Issuer;
                        certInfo.SerialNumber = info->SerialNumber;
                        PCCERT_CONTEXT cert = CertFindCertificateInStore(store, X509_ASN_ENCODING | PKCS_7_ASN_ENCODING, 0,
                                                                         CERT_FIND_SUBJECT_CERT, &certInfo, nullptr);
                        if (cert) {
                            wchar_t name[256] = {};
                            CertGetNameStringW(cert, CERT_NAME_SIMPLE_DISPLAY_TYPE, 0, nullptr, name, 256);
                            signer = QString::fromWCharArray(name);
                            CertFreeCertificateContext(cert);
                        }
                    }
                }
                if (store) CertCloseStore(store, 0);
                if (msg) CryptMsgClose(msg);
            }
        }
        return { state, signer };
#elif defined(Q_OS_ANDROID)
        return { QStringLiteral("android"), QString() };
#else
        return { QStringLiteral("unsigned"), QString() };
#endif
    }
}

PrivacyData::PrivacyData(LinkSecurity* linkSecurity, QObject* parent)
    : QObject(parent)
    , _linkSecurity(linkSecurity)
{
    connect(&_scanWatcher, &QFutureWatcher<QVariantMap>::finished, this, [this]() {
        _sizes = _scanWatcher.result();
        emit sizesChanged();
        _setBusy(false);
    });
    connect(&_deleteWatcher, &QFutureWatcher<void>::finished, this, [this]() {
        _result = _pendingResult;
        emit resultChanged();
        _setBusy(false);
        refresh();
    });
    connect(&_signatureWatcher, &QFutureWatcher<QStringList>::finished, this, [this]() {
        const QStringList r = _signatureWatcher.result();
        _signature = r.value(0);
        _signer = r.value(1);
        emit signatureChanged();
    });
    if (_linkSecurity) {
        connect(_linkSecurity, &LinkSecurity::keyChanged, this, &PrivacyData::_updateAccounts);
    }
}

QVariantMap PrivacyData::_folders() const
{
    AppSettings* app = qgcApp()->toolbox()->settingsManager()->appSettings();
    QVariantMap folders;
    folders[QStringLiteral("logs")]     = QStringList{ app->telemetrySavePath(), app->logSavePath(), app->crashSavePath() };
    folders[QStringLiteral("media")]    = QStringList{ app->videoSavePath(), app->photoSavePath() };
    folders[QStringLiteral("missions")] = QStringList{ app->missionSavePath() };
    return folders;
}

void PrivacyData::refresh()
{
    _updateAccounts();
    reloadSecurityLog();
    if (_signature.isEmpty() && !_signatureWatcher.isRunning()) {
        _signatureWatcher.setFuture(QtConcurrent::run(checkSignature));
    }
    if (_busy) {
        return;
    }
    _setBusy(true);
    _scanWatcher.setFuture(QtConcurrent::run(scanFolders, _folders()));
}

void PrivacyData::_updateAccounts()
{
    QStringList accounts;
    const QStringList names = SecureStore::names();
    auto has = [&names](const QString& part) {
        for (const QString& n : names) {
            if (n.contains(part, Qt::CaseInsensitive)) return true;
        }
        return false;
    };
    if (has(QStringLiteral("RTCM/passwd")))         accounts << QStringLiteral("NTRIP");
    if (has(QStringLiteral("onlineLicenseKey")))    accounts << QStringLiteral("Altitude Angel");
    if (has(QStringLiteral("doodle/")))             accounts << QStringLiteral("Radio");
    if (has(QStringLiteral("Token")))               accounts << QStringLiteral("Map tokens");
    if (has(QStringLiteral("otaPassword")))         accounts << QStringLiteral("OTA");
    if (_linkSecurity && _linkSecurity->hasKey())   accounts << QStringLiteral("Link key");
    if (accounts != _accounts) {
        _accounts = accounts;
        emit accountsChanged();
    }
}

void PrivacyData::reloadSecurityLog()
{
    const QStringList lines = SecurityLog::lines(200);
    if (lines != _securityLog) {
        _securityLog = lines;
        emit securityLogChanged();
    }
}

void PrivacyData::deleteData(const QStringList& keys)
{
    if (_busy || keys.isEmpty()) {
        return;
    }
    const QVariantMap folders = _folders();
    QStringList dirs;
    for (const QString& key : keys) {
        dirs << folders.value(key).toStringList();
    }

    // accounts and keys: everything in the secure store except radio certificate pins (not personal data; keeping
    // them keeps the radio check), plus the MAVLink signing key here (the drone keeps its key: pair it again)
    if (keys.contains(QStringLiteral("accounts"))) {
        SettingsManager* sm = qgcApp()->toolbox()->settingsManager();
        sm->flyViewSettings()->onlineLicenseKey()->setRawValue(QString());
        sm->appSettings()->mapboxToken()->setRawValue(QString());
        sm->appSettings()->esriToken()->setRawValue(QString());
        sm->appSettings()->vworldToken()->setRawValue(QString());
        for (const QString& name : SecureStore::names()) {
            if (!name.startsWith(QStringLiteral("doodlePin/"))) {
                SecureStore::remove(name);
            }
        }
        if (_linkSecurity) {
            _linkSecurity->forgetLocalKey();
        }
    }
    if (keys.contains(QStringLiteral("missions"))) {
        QSettings().remove(QStringLiteral("SimpleMissions"));   // cached mission summaries (S24)
    }
    _pendingResult = QStringLiteral("deleted");
    if (keys.contains(QStringLiteral("settings"))) {
        qgcApp()->deleteAllSettingsNextBoot();
        _pendingResult = QStringLiteral("restart");
    }

    QStringList names = keys;
    SecurityLog::write(QStringLiteral("Data"), QStringLiteral("deleted on this device: ") + names.join(QStringLiteral(", ")));

    _setBusy(true);
    _deleteWatcher.setFuture(QtConcurrent::run(deleteFolders, dirs));
}

void PrivacyData::logEvent(const QString& source, const QString& text)
{
    SecurityLog::write(source, text);
    reloadSecurityLog();
}

void PrivacyData::clearResult()
{
    if (!_result.isEmpty()) {
        _result.clear();
        emit resultChanged();
    }
}

bool PrivacyData::canOpenFolder() const
{
#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
    return false;
#else
    return true;
#endif
}

void PrivacyData::openFolder()
{
    const QString path = qgcApp()->toolbox()->settingsManager()->appSettings()->savePath()->rawValueString();
    if (!path.isEmpty()) {
        QDesktopServices::openUrl(QUrl::fromLocalFile(path));
    }
}

void PrivacyData::_setBusy(bool busy)
{
    if (_busy != busy) {
        _busy = busy;
        emit busyChanged();
    }
}
