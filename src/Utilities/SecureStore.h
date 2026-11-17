/****************************************************************************
 * AQGC — small secure store for secrets (CE RED 3.3(d)/(e), EN 18031 SSM, Figma 00 Overview §10, 2026-11-17).
 * Windows: DPAPI (current user) → base64 in QSettings group "SecureStore". Other platforms: app-private settings
 * (TODO: Android Keystore). Values are never logged or exported by this class.
 ****************************************************************************/
#pragma once

#include <QByteArray>
#include <QString>
#include <QStringList>

namespace SecureStore {
    /// true when values are protected by the OS (Windows DPAPI); false = app-private settings only
    bool        osProtected ();
    void        put         (const QString& name, const QByteArray& value);
    QByteArray  get         (const QString& name);          ///< empty when missing or unreadable
    void        remove      (const QString& name);
    bool        contains    (const QString& name);
    QStringList names       ();                             ///< stored names (never the values)

    // raw DPAPI helpers (Windows; elsewhere they return the input / empty)
    QByteArray  protect     (const QByteArray& plain);
    QByteArray  unprotect   (const QByteArray& blob);
}
