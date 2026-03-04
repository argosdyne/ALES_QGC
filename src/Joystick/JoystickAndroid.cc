#include "JoystickAndroid.h"

#include "QGCApplication.h"

#include <QQmlEngine>
#include <QSet>
#include <QVector>
#include <cmath>

int JoystickAndroid::_androidBtnListCount;
int *JoystickAndroid::_androidBtnList;
int JoystickAndroid::ACTION_DOWN;
int JoystickAndroid::ACTION_UP;
QMutex JoystickAndroid::m_mutex;

static void clear_jni_exception()
{
    QAndroidJniEnvironment jniEnv;
    if (jniEnv->ExceptionCheck()) {
        jniEnv->ExceptionDescribe();
        jniEnv->ExceptionClear();
    }
}

JoystickAndroid::JoystickAndroid(const QString& name, int axisCount, int buttonCount, int id, MultiVehicleManager* multiVehicleManager)
    : Joystick(name,axisCount,buttonCount,0,multiVehicleManager)
    , deviceId(id)
{
    int i;
    
    QAndroidJniEnvironment env;
    QAndroidJniObject inputDevice = QAndroidJniObject::callStaticObjectMethod("android/view/InputDevice", "getDevice", "(I)Landroid/view/InputDevice;", id);

    //set button mapping (number->code)
    jintArray b = env->NewIntArray(_androidBtnListCount);
    env->SetIntArrayRegion(b,0,_androidBtnListCount,_androidBtnList);

    QAndroidJniObject btns = inputDevice.callObjectMethod("hasKeys", "([I)[Z", b);
    jbooleanArray jSupportedButtons = btns.object<jbooleanArray>();
    jboolean* supportedButtons = env->GetBooleanArrayElements(jSupportedButtons, nullptr);
    //create a mapping table (btnCode) that maps button number with button code
    btnValue = new bool[_buttonCount];
    btnCode = new int[_buttonCount];
    int c = 0;
    for (i = 0; i < _androidBtnListCount; i++) {
        if (supportedButtons[i]) {
            btnValue[c] = false;
            btnCode[c] = _androidBtnList[i];
            c++;
        }
    }

    env->ReleaseBooleanArrayElements(jSupportedButtons, supportedButtons, 0);

    // set axis mapping (number->code)
    axisValue = new int[_axisCount];
    axisCode = new int[_axisCount];
    axisMin = new float[_axisCount];
    axisMax = new float[_axisCount];
    axisFlat = new float[_axisCount];

    for (i = 0; i < _axisCount; i++) {
        axisCode[i] = -1;
        axisValue[i] = 0;
        axisMin[i] = -1.0f;
        axisMax[i] = 1.0f;
        axisFlat[i] = 0.0f;
    }

    const int SOURCE_JOYSTICK = QAndroidJniObject::getStaticField<jint>("android/view/InputDevice", "SOURCE_JOYSTICK");
    const int AXIS_X = QAndroidJniObject::getStaticField<jint>("android/view/MotionEvent", "AXIS_X");
    const int AXIS_Y = QAndroidJniObject::getStaticField<jint>("android/view/MotionEvent", "AXIS_Y");
    const int AXIS_RX = QAndroidJniObject::getStaticField<jint>("android/view/MotionEvent", "AXIS_RX");
    const int AXIS_RY = QAndroidJniObject::getStaticField<jint>("android/view/MotionEvent", "AXIS_RY");
    const int AXIS_Z = QAndroidJniObject::getStaticField<jint>("android/view/MotionEvent", "AXIS_Z");
    const int AXIS_RZ = QAndroidJniObject::getStaticField<jint>("android/view/MotionEvent", "AXIS_RZ");

    struct AxisRange {
        int axis = -1;
        float min = -1.0f;
        float max = 1.0f;
        float flat = 0.0f;
    };

    QAndroidJniObject rangeListNative = inputDevice.callObjectMethod("getMotionRanges", "()Ljava/util/List;");
    const int rangeCount = rangeListNative.callMethod<jint>("size");
    QVector<AxisRange> availableRanges;
    availableRanges.reserve(rangeCount);

    QSet<int> seenAxes;
    for (i = 0; i < rangeCount; i++) {
        QAndroidJniObject range = rangeListNative.callObjectMethod("get", "(I)Ljava/lang/Object;",i);
        const int source = range.callMethod<jint>("getSource");
        if ((source & SOURCE_JOYSTICK) != SOURCE_JOYSTICK) {
            continue;
        }

        const int axis = range.callMethod<jint>("getAxis");
        if (seenAxes.contains(axis)) {
            continue;
        }

        seenAxes.insert(axis);
        AxisRange axisRange;
        axisRange.axis = axis;
        axisRange.min = range.callMethod<jfloat>("getMin");
        axisRange.max = range.callMethod<jfloat>("getMax");
        axisRange.flat = range.callMethod<jfloat>("getFlat");
        availableRanges.append(axisRange);
    }

    int axisIndex = 0;
    QSet<int> assignedAxes;

    auto appendAxisByCode = [&](int wantedAxis) -> bool {
        for (const AxisRange& axisRange: availableRanges) {
            if (axisRange.axis != wantedAxis) {
                continue;
            }
            if (axisIndex >= _axisCount) {
                return false;
            }
            axisCode[axisIndex] = axisRange.axis;
            axisMin[axisIndex] = axisRange.min;
            axisMax[axisIndex] = axisRange.max;
            axisFlat[axisIndex] = axisRange.flat;
            assignedAxes.insert(axisRange.axis);
            axisIndex++;
            return true;
        }
        return false;
    };

    // Left stick preferred mapping (always try AXIS_X/AXIS_Y first)
    appendAxisByCode(AXIS_X);
    appendAxisByCode(AXIS_Y);

    // Right stick preferred mapping with fallback to Z/RZ if RX/RY are not available
    if (!appendAxisByCode(AXIS_RX)) {
        appendAxisByCode(AXIS_Z);
    }
    if (!appendAxisByCode(AXIS_RY)) {
        appendAxisByCode(AXIS_RZ);
    }

    for (const AxisRange& axisRange: availableRanges) {
        if (assignedAxes.contains(axisRange.axis)) {
            continue;
        }
        if (axisIndex >= _axisCount) {
            break;
        }
        axisCode[axisIndex] = axisRange.axis;
        axisMin[axisIndex] = axisRange.min;
        axisMax[axisIndex] = axisRange.max;
        axisFlat[axisIndex] = axisRange.flat;
        axisIndex++;
    }

    qCDebug(JoystickLog) << "axis:" <<_axisCount << "buttons:" <<_buttonCount;
    QtAndroidPrivate::registerGenericMotionEventListener(this);
    QtAndroidPrivate::registerKeyEventListener(this);
}

JoystickAndroid::~JoystickAndroid() {
    delete[] btnCode;
    delete[] axisCode;
    delete[] btnValue;
    delete[] axisValue;
    delete[] axisMin;
    delete[] axisMax;
    delete[] axisFlat;

    QtAndroidPrivate::unregisterGenericMotionEventListener(this);
    QtAndroidPrivate::unregisterKeyEventListener(this);
}


QMap<QString, Joystick*> JoystickAndroid::discover(MultiVehicleManager* _multiVehicleManager) {
    static QMap<QString, Joystick*> ret;

    QMutexLocker lock(&m_mutex);

    QAndroidJniEnvironment env;
    QAndroidJniObject o = QAndroidJniObject::callStaticObjectMethod<jintArray>("android/view/InputDevice", "getDeviceIds");
    jintArray jarr = o.object<jintArray>();
    int sz = env->GetArrayLength(jarr);
    jint *buff = env->GetIntArrayElements(jarr, nullptr);

    int SOURCE_GAMEPAD = QAndroidJniObject::getStaticField<jint>("android/view/InputDevice", "SOURCE_GAMEPAD");
    int SOURCE_JOYSTICK = QAndroidJniObject::getStaticField<jint>("android/view/InputDevice", "SOURCE_JOYSTICK");

    QList<QString> names;

    for (int i = 0; i < sz; ++i) {
        QAndroidJniObject inputDevice = QAndroidJniObject::callStaticObjectMethod("android/view/InputDevice", "getDevice", "(I)Landroid/view/InputDevice;", buff[i]);
        int sources = inputDevice.callMethod<jint>("getSources", "()I");
        if (((sources & SOURCE_GAMEPAD) != SOURCE_GAMEPAD) //check if the input device is interesting to us
                && ((sources & SOURCE_JOYSTICK) != SOURCE_JOYSTICK)) continue;

        // get id and name
        QString id = inputDevice.callObjectMethod("getDescriptor", "()Ljava/lang/String;").toString();
        QString name = inputDevice.callObjectMethod("getName", "()Ljava/lang/String;").toString();

        names.push_back(name);

        if (ret.contains(name)) {
            continue;
        }

        // get number of axis
        QAndroidJniObject rangeListNative = inputDevice.callObjectMethod("getMotionRanges", "()Ljava/util/List;");
        const int rangeCount = rangeListNative.callMethod<jint>("size");
        QSet<int> axisCodes;
        for (int j = 0; j < rangeCount; j++) {
            QAndroidJniObject range = rangeListNative.callObjectMethod("get", "(I)Ljava/lang/Object;", j);
            const int source = range.callMethod<jint>("getSource");
            if ((source & SOURCE_JOYSTICK) != SOURCE_JOYSTICK) {
                continue;
            }

            const int axisCode = range.callMethod<jint>("getAxis");
            axisCodes.insert(axisCode);
        }
        int axisCount = axisCodes.size();

        // get number of buttons
        jintArray a = env->NewIntArray(_androidBtnListCount);
        env->SetIntArrayRegion(a,0,_androidBtnListCount,_androidBtnList);
        QAndroidJniObject btns = inputDevice.callObjectMethod("hasKeys", "([I)[Z", a);
        jbooleanArray jSupportedButtons = btns.object<jbooleanArray>();
        jboolean* supportedButtons = env->GetBooleanArrayElements(jSupportedButtons, nullptr);
        int buttonCount = 0;
        for (int j=0;j<_androidBtnListCount;j++)
            if (supportedButtons[j]) buttonCount++;
        env->ReleaseBooleanArrayElements(jSupportedButtons, supportedButtons, 0);

        qCDebug(JoystickLog) << "\t" << name << "id:" << buff[i] << "axes:" << axisCount << "buttons:" << buttonCount;

        ret[name] = new JoystickAndroid(name, axisCount, buttonCount, buff[i], _multiVehicleManager);
    }

    for (auto i = ret.begin(); i != ret.end();) {
        if (!names.contains(i.key())) {
            i = ret.erase(i);
        } else {
            i++;
        }
    }

    env->ReleaseIntArrayElements(jarr, buff, 0);

    return ret;
}


bool JoystickAndroid::handleKeyEvent(jobject event) {
    QJNIObjectPrivate ev(event);
    QMutexLocker lock(&m_mutex);
    const int _deviceId = ev.callMethod<jint>("getDeviceId", "()I");
    if (_deviceId!=deviceId) return false;
 
    const int action = ev.callMethod<jint>("getAction", "()I");
    const int keyCode = ev.callMethod<jint>("getKeyCode", "()I");

    for (int i = 0; i <_buttonCount; i++) {
        if (btnCode[i] == keyCode) {
            if (action == ACTION_DOWN) btnValue[i] = true;
            if (action == ACTION_UP)   btnValue[i] = false;
            return true;
        }
    }
    return false;
}

bool JoystickAndroid::handleGenericMotionEvent(jobject event) {
    QJNIObjectPrivate ev(event);
    QMutexLocker lock(&m_mutex);
    const int _deviceId = ev.callMethod<jint>("getDeviceId", "()I");
    if (_deviceId!=deviceId) return false;
 
    for (int i = 0; i <_axisCount; i++) {
        if (axisCode[i] < 0) {
            continue;
        }

        const float rawValue = ev.callMethod<jfloat>("getAxisValue", "(I)F", axisCode[i]);
        const float minValue = axisMin[i];
        const float maxValue = axisMax[i];
        const float flatValue = axisFlat[i];

        float normalized = rawValue;
        if (maxValue > minValue) {
            const float center = (maxValue + minValue) * 0.5f;
            const float halfRange = (maxValue - minValue) * 0.5f;
            if (halfRange > 0.0001f) {
                normalized = (rawValue - center) / halfRange;
                const float normalizedDeadzone = flatValue / halfRange;
                if (std::fabs(normalized) <= normalizedDeadzone) {
                    normalized = 0.0f;
                }
            } else {
                normalized = 0.0f;
            }
        }

        normalized = qBound(-1.0f, normalized, 1.0f);
        axisValue[i] = static_cast<int>(normalized * 32767.0f);
    }
    return true;
}

bool JoystickAndroid::_open(void) {
    return true;
}

void JoystickAndroid::_close(void) {
}

bool JoystickAndroid::_update(void)
{
    return true;
}

bool JoystickAndroid::_getButton(int i) {
    return btnValue[ i ];
}

int JoystickAndroid::_getAxis(int i) {
    return axisValue[ i ];
}

bool JoystickAndroid::_getHat(int hat,int i) {
    Q_UNUSED(hat);
    Q_UNUSED(i);
    return false;
}

static JoystickManager *_manager = nullptr;

//helper method
bool JoystickAndroid::init(JoystickManager *manager) {
    _manager = manager;

    //this gets list of all possible buttons - this is needed to check how many buttons our gamepad supports
    //instead of the whole logic below we could have just a simple array of hardcoded int values as these 'should' not change

    //int JoystickAndroid::_androidBtnListCount;
    _androidBtnListCount = 31;
    static int ret[31]; //there are 31 buttons in total accordingy to the API
    int i;
    //int *JoystickAndroid::
    _androidBtnList = ret;

    clear_jni_exception();
    for (i = 1; i <= 16; i++) {
        QString name = "KEYCODE_BUTTON_"+QString::number(i);
        ret[i-1] = QAndroidJniObject::getStaticField<jint>("android/view/KeyEvent", name.toStdString().c_str());
    }
    i--;

    ret[i++] = QAndroidJniObject::getStaticField<jint>("android/view/KeyEvent", "KEYCODE_BUTTON_A");
    ret[i++] = QAndroidJniObject::getStaticField<jint>("android/view/KeyEvent", "KEYCODE_BUTTON_B");
    ret[i++] = QAndroidJniObject::getStaticField<jint>("android/view/KeyEvent", "KEYCODE_BUTTON_C");
    ret[i++] = QAndroidJniObject::getStaticField<jint>("android/view/KeyEvent", "KEYCODE_BUTTON_L1");
    ret[i++] = QAndroidJniObject::getStaticField<jint>("android/view/KeyEvent", "KEYCODE_BUTTON_L2");
    ret[i++] = QAndroidJniObject::getStaticField<jint>("android/view/KeyEvent", "KEYCODE_BUTTON_R1");
    ret[i++] = QAndroidJniObject::getStaticField<jint>("android/view/KeyEvent", "KEYCODE_BUTTON_R2");
    ret[i++] = QAndroidJniObject::getStaticField<jint>("android/view/KeyEvent", "KEYCODE_BUTTON_MODE");
    ret[i++] = QAndroidJniObject::getStaticField<jint>("android/view/KeyEvent", "KEYCODE_BUTTON_SELECT");
    ret[i++] = QAndroidJniObject::getStaticField<jint>("android/view/KeyEvent", "KEYCODE_BUTTON_START");
    ret[i++] = QAndroidJniObject::getStaticField<jint>("android/view/KeyEvent", "KEYCODE_BUTTON_THUMBL");
    ret[i++] = QAndroidJniObject::getStaticField<jint>("android/view/KeyEvent", "KEYCODE_BUTTON_THUMBR");
    ret[i++] = QAndroidJniObject::getStaticField<jint>("android/view/KeyEvent", "KEYCODE_BUTTON_X");
    ret[i++] = QAndroidJniObject::getStaticField<jint>("android/view/KeyEvent", "KEYCODE_BUTTON_Y");
    ret[i++] = QAndroidJniObject::getStaticField<jint>("android/view/KeyEvent", "KEYCODE_BUTTON_Z");

    ACTION_DOWN = QAndroidJniObject::getStaticField<jint>("android/view/KeyEvent", "ACTION_DOWN");
    ACTION_UP = QAndroidJniObject::getStaticField<jint>("android/view/KeyEvent", "ACTION_UP");

    return true;
}

static const char kJniClassName[] {"org/mavlink/qgroundcontrol/QGCActivity"};

static void jniUpdateAvailableJoysticks(JNIEnv *envA, jobject thizA)
{
    Q_UNUSED(envA);
    Q_UNUSED(thizA);

    if (_manager != nullptr) {
        qCDebug(JoystickLog) << "jniUpdateAvailableJoysticks triggered";
        emit _manager->updateAvailableJoysticksSignal();
    }
}

void JoystickAndroid::setNativeMethods()
{
    qCDebug(JoystickLog) << "Registering Native Functions";

    //  REGISTER THE C++ FUNCTION WITH JNI
    JNINativeMethod javaMethods[] {
        {"nativeUpdateAvailableJoysticks", "()V", reinterpret_cast<void *>(jniUpdateAvailableJoysticks)}
    };

    clear_jni_exception();
    QAndroidJniEnvironment jniEnv;
    jclass objectClass = jniEnv->FindClass(kJniClassName);
    if(!objectClass) {
        clear_jni_exception();
        qWarning() << "Couldn't find class:" << kJniClassName;
        return;
    }

    jint val = jniEnv->RegisterNatives(objectClass, javaMethods, sizeof(javaMethods) / sizeof(javaMethods[0]));

    if (val < 0) {
        qWarning() << "Error registering methods: " << val;
    } else {
        qCDebug(JoystickLog) << "Native Functions Registered";
    }
    clear_jni_exception();
}
