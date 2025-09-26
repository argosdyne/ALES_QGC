#include "TargetObject.h"

TargetObject::TargetObject(float x, float y, float x2, float y2, QString objectId, float credibility, QObject* parent)
	: QObject(parent)
	, _isCircle(false)
	, _x(x)
	, _y(y)
	, _width(x2 - x)
	, _height(y2 - y)
    , _credibility(credibility)
	, _dirty(true)
{
    qsizetype index = objectId.indexOf('#');
    if(index > 1) {
        _name = objectId.left(index);
        _objectColor = QColor(objectId.right(objectId.size() - index));
    } else {
        _name = objectId;
        _objectColor = discernColor.value(objectId, QColor("black"));
    }
}

void TargetObject::setItPropertys(float x, float y, float x2, float y2, QString objectId, bool isCircle,
				  float credibility, bool update)
{
	_x = x;
	_y = y;
	_width = x2 - x;
	_height = y2 - y;
    qsizetype index = objectId.indexOf('#');
    if(index > 1) {
        _name = objectId.left(index);
        _objectColor = QColor(objectId.right(objectId.size() - index));
    } else {
        _name = objectId;
        _objectColor = discernColor.value(objectId, QColor("black"));
    }
	_name = objectId;
	_isCircle = isCircle;
	_credibility = credibility;
	_dirty = true;
	if(update) { emit updateProperty(); }
}

void TargetObject::cleanItstyle(bool update)
{
	_x = _y = _width = _height = _credibility = 0;
	_name =  "";
	_objectColor = QColor("transparent");
	_dirty = false;
	if(update) { emit updateProperty(); }
}
