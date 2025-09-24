#ifndef TARGETOBJECT_H
#define TARGETOBJECT_H
#include <QColor>
#include <QObject>
#include <QMap>

static QMap<QString, QColor> discernColor = {
	{"aeroplane", QColor(0, 0, 0)}, {"bicycle", QColor(0, 0, 0)},
	{"bird", QColor(0, 0, 0)}, {"boat", QColor(0, 0, 0)},
	{"bottle", QColor(0, 0, 0)}, {"bus", QColor(255, 255, 0)},
	{"car", QColor(0, 0, 255)}, {"cat", QColor(255, 0, 255)},
	{"chair", QColor(0, 0, 0)}, {"cow", QColor(0, 0, 0)},
	{"diningtable", QColor(0, 0, 0)}, {"dog", QColor(0, 255, 255)},
    {"horse", QColor(255, 0, 0)}, {"bike", QColor(0, 0, 0)},
	{"person", QColor(0, 255, 0)}, {"pottedplant", QColor(0, 0, 0)},
	{"sheep", QColor(0, 0, 0)}, {"sofa", QColor(0, 0, 0)},
	{"train", QColor(0, 0, 0)}, {"tvmonitor", QColor(0, 0, 0)},
    {"object", QColor(255, 0, 0)}, {"tracking_object", QColor(255, 0, 0)},
    {"truck", QColor(255, 255, 0)}
};

class TargetObject : public QObject
{
	Q_OBJECT
public:
	Q_PROPERTY(bool isCircle READ isCircle NOTIFY updateProperty)
	Q_PROPERTY(float x READ x NOTIFY updateProperty)
	Q_PROPERTY(float y READ y NOTIFY updateProperty)
	Q_PROPERTY(float width READ width NOTIFY updateProperty)
	Q_PROPERTY(float height READ height NOTIFY updateProperty)
	Q_PROPERTY(QString name READ name NOTIFY updateProperty)
	Q_PROPERTY(float credibility READ credibility NOTIFY updateProperty)
	Q_PROPERTY(QColor objectColor READ objectColor NOTIFY updateProperty)
    TargetObject(float x, float y, float x2, float y2, QString objectId, float credibility = 0.0f, QObject* parent = nullptr);

	bool isCircle() { return _isCircle; }
	float x() { return _x; }
	float y() { return _y; }
	float width() { return _width; }
	float height() { return _height; }
	QString name() { return _name; }
	float credibility() { return _credibility; }
	QColor objectColor() { return _objectColor; }
	bool dirty() { return _dirty; }

	void cleanItstyle(bool update = true);
	void setItPropertys(float x, float y, float x2, float y2, QString objectId, bool isCircle = false,
			    float credibility = 1.0f, bool update = true);

signals:
	void updateProperty();

private:
	bool _isCircle;
	float _x;
	float _y;
	float _width;
	float _height;
	QString _name;
	float _credibility;
	QColor _objectColor;
	bool _dirty;
};

#endif // TARGETOBJECT_H
