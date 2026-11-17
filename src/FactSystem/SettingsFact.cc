/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


#include "SettingsFact.h"
#include "QGCCorePlugin.h"
#include "QGCApplication.h"
#include "SecureStore.h"

#include <QSettings>

// AQGC (CE RED 3.3(d)/(e), EN 18031, 2026-11-17): passwords, licence keys and tokens are kept in SecureStore
// (Windows DPAPI) under "<group>/<name>", not as plain text in the settings file. A plain value left by an older
// build is moved there once. Both modes.
static bool _isSecretSetting(const QString& name)
{
    static const QStringList secrets = { "passwd", "otaPassword", "onlineLicenseKey", "mapboxToken", "esriToken", "vworldToken" };
    return secrets.contains(name);
}

static QString _secretName(const QString& group, const QString& name)
{
    return group.isEmpty() ? name : group + "/" + name;
}

// settings must be in the group; moves a plain value (if any) into the secure store and removes it from the file
static void _moveSecret(QSettings& settings, const QString& group, const QString& name)
{
    if (!settings.contains(name)) {
        return;
    }
    const QString secretName = _secretName(group, name);
    const QString plain = settings.value(name).toString();
    if (!plain.isEmpty() && !SecureStore::contains(secretName)) {
        SecureStore::put(secretName, plain.toUtf8());
    }
    settings.remove(name);
}

void SettingsFact::moveSecretsToSecureStore(void)
{
    QSettings settings;
    for (const QString& group : settings.childGroups()) {
        if (group == QStringLiteral("SecureStore")) {
            continue;
        }
        settings.beginGroup(group);
        for (const QString& key : settings.childKeys()) {
            if (_isSecretSetting(key)) {
                _moveSecret(settings, group, key);
            }
        }
        settings.endGroup();
    }
}

SettingsFact::SettingsFact(QObject* parent)
    : Fact(parent)
{    
    QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership);
}

SettingsFact::SettingsFact(QString settingsGroup, FactMetaData* metaData, QObject* parent)
    : Fact          (0, metaData->name(), metaData->type(), parent)
    , _settingsGroup(settingsGroup)
    , _visible      (true)
{
    QSettings settings;

    if (!_settingsGroup.isEmpty()) {
        settings.beginGroup(_settingsGroup);
    }

    // Allow core plugin a chance to override the default value
    _visible = qgcApp()->toolbox()->corePlugin()->adjustSettingMetaData(settingsGroup, *metaData);
    setMetaData(metaData);

    if (metaData->defaultValueAvailable()) {
        QVariant rawDefaultValue = metaData->rawDefaultValue();
        if (qgcApp()->runningUnitTests()) {
            // Don't use saved settings
            _rawValue = rawDefaultValue;
        } else {
            if (_visible) {
                QVariant typedValue;
                QString errorString;
                QVariant stored = settings.value(_name, rawDefaultValue);
                if (_isSecretSetting(_name)) {
                    const QString secretName = _secretName(_settingsGroup, _name);
                    _moveSecret(settings, _settingsGroup, _name);
                    stored = SecureStore::contains(secretName) ? QVariant(QString::fromUtf8(SecureStore::get(secretName))) : rawDefaultValue;
                }
                metaData->convertAndValidateRaw(stored, true /* conertOnly */, typedValue, errorString);
                _rawValue = typedValue;
            } else {
                // Setting is not visible, force to default value always
                settings.setValue(_name, rawDefaultValue);
                _rawValue = rawDefaultValue;
            }
        }
    }

    connect(this, &Fact::rawValueChanged, this, &SettingsFact::_rawValueChanged);
}

SettingsFact::SettingsFact(const SettingsFact& other, QObject* parent)
    : Fact(other, parent)
{
    *this = other;
}

const SettingsFact& SettingsFact::operator=(const SettingsFact& other)
{
    Fact::operator=(other);
    
    _settingsGroup = other._settingsGroup;

    return *this;
}

void SettingsFact::_rawValueChanged(QVariant value)
{
    QSettings settings;

    if (!_settingsGroup.isEmpty()) {
        settings.beginGroup(_settingsGroup);
    }

    if (_isSecretSetting(_name)) {
        const QString secretName = _secretName(_settingsGroup, _name);
        const QString text = value.toString();
        if (text.isEmpty()) {
            SecureStore::remove(secretName);
        } else {
            SecureStore::put(secretName, text.toUtf8());
        }
        settings.remove(_name);
        return;
    }

    settings.setValue(_name, value);
}
