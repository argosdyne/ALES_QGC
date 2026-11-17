/****************************************************************************
 * AQGC — secure store, see SecureStore.h
 ****************************************************************************/

#include "SecureStore.h"

#include <QSettings>

#ifdef Q_OS_WIN
#include <windows.h>
#include <wincrypt.h>
#endif

namespace {
    const char* kGroup = "SecureStore";

#ifdef Q_OS_WIN
    QByteArray dpapi(const QByteArray& in, bool encrypt)
    {
        DATA_BLOB src;
        src.pbData = reinterpret_cast<BYTE*>(const_cast<char*>(in.constData()));
        src.cbData = static_cast<DWORD>(in.size());
        DATA_BLOB out = {};
        const BOOL ok = encrypt
            ? CryptProtectData(&src, L"alesQGC secret", nullptr, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &out)
            : CryptUnprotectData(&src, nullptr, nullptr, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &out);
        if (!ok) {
            return QByteArray();
        }
        QByteArray result(reinterpret_cast<const char*>(out.pbData), static_cast<int>(out.cbData));
        SecureZeroMemory(out.pbData, out.cbData);
        LocalFree(out.pbData);
        return result;
    }
#endif
}

bool SecureStore::osProtected()
{
#ifdef Q_OS_WIN
    return true;
#else
    return false;
#endif
}

QByteArray SecureStore::protect(const QByteArray& plain)
{
#ifdef Q_OS_WIN
    return dpapi(plain, true);
#else
    return plain;
#endif
}

QByteArray SecureStore::unprotect(const QByteArray& blob)
{
#ifdef Q_OS_WIN
    return dpapi(blob, false);
#else
    return blob;
#endif
}

void SecureStore::put(const QString& name, const QByteArray& value)
{
    QSettings settings;
    settings.beginGroup(QString::fromLatin1(kGroup));
    settings.setValue(name, protect(value).toBase64());
    settings.endGroup();
}

QByteArray SecureStore::get(const QString& name)
{
    QSettings settings;
    settings.beginGroup(QString::fromLatin1(kGroup));
    const QByteArray blob = QByteArray::fromBase64(settings.value(name).toByteArray());
    settings.endGroup();
    return blob.isEmpty() ? QByteArray() : unprotect(blob);
}

void SecureStore::remove(const QString& name)
{
    QSettings settings;
    settings.beginGroup(QString::fromLatin1(kGroup));
    settings.remove(name);
    settings.endGroup();
}

bool SecureStore::contains(const QString& name)
{
    QSettings settings;
    settings.beginGroup(QString::fromLatin1(kGroup));
    const bool has = settings.contains(name);
    settings.endGroup();
    return has;
}
