/****************************************************************************
 * AQGC Simple UI — admin PIN storage (S12). Header only, so the app (CustomPlugin) and the Simple UI
 * test runner use the same code.
 *
 * Stored form: "pbkdf2-sha256$<iterations>$<salt hex>$<key hex>" (PBKDF2-HMAC-SHA256, 16-byte random salt,
 * 32-byte key). A 6-digit PIN has only 10^6 values, so the hash does not make a copied settings file safe
 * against a determined attacker; it keeps the PIN from being read in the settings file and makes each guess
 * cost the PBKDF2 work.
 * A stored plain 6-digit PIN (older versions) is still accepted by check(); the dialog then stores the hash.
 ****************************************************************************/
#pragma once

#include <QByteArray>
#include <QCryptographicHash>
#include <QPasswordDigestor>
#include <QRandomGenerator>
#include <QRegularExpression>
#include <QString>
#include <QStringList>

namespace SimplePinHash {

static const int kIterations = 20000;

inline QString hashWithSalt(const QString& pin, const QByteArray& salt, int iterations)
{
    const QByteArray key = QPasswordDigestor::deriveKeyPbkdf2(QCryptographicHash::Sha256, pin.toUtf8(), salt, iterations, 32);
    return QStringLiteral("pbkdf2-sha256$%1$%2$%3").arg(iterations)
            .arg(QString::fromLatin1(salt.toHex()), QString::fromLatin1(key.toHex()));
}

inline QString hash(const QString& pin)
{
    QByteArray salt(16, Qt::Uninitialized);
    for (int i = 0; i < salt.size(); i++) {
        salt[i] = static_cast<char>(QRandomGenerator::system()->bounded(256));
    }
    return hashWithSalt(pin, salt, kIterations);
}

inline bool isPlainPin(const QString& stored)
{
    static const QRegularExpression re(QStringLiteral("^[0-9]{6}$"));
    return re.match(stored).hasMatch();
}

inline bool isHash(const QString& stored)
{
    static const QRegularExpression re(QStringLiteral("^pbkdf2-sha256\\$([0-9]{1,7})\\$([0-9a-f]{32})\\$([0-9a-f]{64})$"));
    const QRegularExpressionMatch m = re.match(stored);
    if (!m.hasMatch()) {
        return false;
    }
    const int iterations = m.captured(1).toInt();
    return iterations >= 1000 && iterations <= 1000000;
}

// constant-time compare of two equal-length strings
inline bool sameText(const QString& a, const QString& b)
{
    if (a.size() != b.size()) {
        return false;
    }
    int diff = 0;
    for (int i = 0; i < a.size(); i++) {
        diff |= a.at(i).unicode() ^ b.at(i).unicode();
    }
    return diff == 0;
}

inline bool check(const QString& pin, const QString& stored)
{
    if (!isPlainPin(pin)) {
        return false;
    }
    if (isPlainPin(stored)) {
        return sameText(pin, stored);
    }
    if (!isHash(stored)) {
        return false;
    }
    const QStringList parts = stored.split(QLatin1Char('$'));
    return sameText(hashWithSalt(pin, QByteArray::fromHex(parts[2].toLatin1()), parts[1].toInt()), stored);
}

} // namespace SimplePinHash
