/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include "QGCMapCircle.h"
#include "QGCMAVLink.h"
#include <QColor>
/// The QGCFenceCircle class provides a cicle used by GeoFence support.
class QGCFenceCircle : public QGCMapCircle
{
    Q_OBJECT

public:
    QGCFenceCircle(QObject* parent = nullptr);
    QGCFenceCircle(const QGeoCoordinate& center, double radius, bool inclusion, QObject* parent = nullptr);
    QGCFenceCircle(const QGCFenceCircle& other, QObject* parent = nullptr);

    const QGCFenceCircle& operator=(const QGCFenceCircle& other);

    Q_PROPERTY(bool inclusion READ inclusion WRITE setInclusion NOTIFY inclusionChanged)
    Q_PROPERTY(bool altitudeBandEnabled READ altitudeBandEnabled WRITE setAltitudeBandEnabled NOTIFY altitudeBandEnabledChanged)
    Q_PROPERTY(double altitudeMin READ altitudeMin WRITE setAltitudeMin NOTIFY altitudeMinChanged)
    Q_PROPERTY(double altitudeMax READ altitudeMax WRITE setAltitudeMax NOTIFY altitudeMaxChanged)
    Q_PROPERTY(int altitudeFrame READ altitudeFrame WRITE setAltitudeFrame NOTIFY altitudeFrameChanged)
    Q_PROPERTY(int inclusionGroup READ inclusionGroup WRITE setInclusionGroup NOTIFY inclusionGroupChanged)

    Q_PROPERTY(QColor colorInclusion READ colorInclusion WRITE setcolorInclusion NOTIFY colorInclusionChanged)

    Q_PROPERTY(double strokeOpacity READ strokeOpacity WRITE setstrokeOpacity NOTIFY strokeOpcaityChanged)


    /// Saves the QGCFenceCircle to the json object.
    ///     @param json Json object to save to
    void saveToJson(QJsonObject& json);

    /// Load a QGCFenceCircle from json
    ///     @param json Json object to load from
    ///     @param errorString Error string if return is false
    /// @return true: success, false: failure (errorString set)
    bool loadFromJson(const QJsonObject& json, QString& errorString);

    // Property methods

    bool inclusion      (void) const { return _inclusion; }
    void setInclusion   (bool inclusion);
    bool altitudeBandEnabled (void) const { return _altitudeBandEnabled; }
    void setAltitudeBandEnabled(bool altitudeBandEnabled);
    double altitudeMin  (void) const { return _altitudeMin; }
    void setAltitudeMin (double altitudeMin);
    double altitudeMax  (void) const { return _altitudeMax; }
    void setAltitudeMax (double altitudeMax);
    int altitudeFrame   (void) const { return _altitudeFrame; }
    void setAltitudeFrame(int altitudeFrame);
    int inclusionGroup  (void) const { return _inclusionGroup; }
    void setInclusionGroup(int inclusionGroup);
    void setcolorInclusion(QColor colorInclusion);
    QColor colorInclusion (void) const {return _colorInclusion;}

    void setstrokeOpacity(double opacity);
    double strokeOpacity (void) const {return _strokeOpacity;}


signals:
    void inclusionChanged(bool inclusion);
    void altitudeBandEnabledChanged(bool altitudeBandEnabled);
    void altitudeMinChanged(double altitudeMin);
    void altitudeMaxChanged(double altitudeMax);
    void altitudeFrameChanged(int altitudeFrame);
    void inclusionGroupChanged(int inclusionGroup);
    void colorInclusionChanged ();
    void strokeOpcaityChanged();

private slots:
    void _setDirty(void);

private:
    void _init(void);

    bool _inclusion;
    bool _altitudeBandEnabled = false;
    double _altitudeMin = 0.0;
    double _altitudeMax = 0.0;
    int _altitudeFrame = MAV_FRAME_GLOBAL_RELATIVE_ALT;
    int _inclusionGroup = 0;

    QColor _colorInclusion;

    double _strokeOpacity;

    static const int _jsonCurrentVersion = 1;

    static const char* _jsonInclusionKey;
    static const char* _jsonAltitudeBandEnabledKey;
    static const char* _jsonAltitudeMinKey;
    static const char* _jsonAltitudeMaxKey;
    static const char* _jsonAltitudeFrameKey;
    static const char* _jsonInclusionGroupKey;
};
