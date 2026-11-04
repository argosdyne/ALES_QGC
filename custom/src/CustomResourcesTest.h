#pragma once

#include "UnitTest.h"

/// The custom build replaces the root qrc files with custom/qgroundcontrol.qrc and
/// custom/qgcresources.qrc, which are maintained by hand. Resources that code loads by path
/// must be in them.
class CustomResourcesTest : public UnitTest
{
    Q_OBJECT

private slots:
    void _resourcesPresent(void);
};
