/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


/**
 * @file
 *   @brief QGC Video Receiver
 *   @author Gus Grubba <gus@auterion.com>
 */

#include "GstVideoReceiver.h"

#include <QDebug>
#include <QUrl>
#include <QDateTime>
#include <QSysInfo>

#include <gst/rtsp/gstrtsptransport.h>

QGC_LOGGING_CATEGORY(VideoReceiverLog, "VideoReceiverLog")
QGC_LOGGING_CATEGORY(GStreamLog, "GStreamLog")

namespace {

constexpr guint kRtspUdpReconnectTimeoutUs = 5000000u;
constexpr guint kRtspUdpLatencyMs = 150;
constexpr gboolean kRtspDropOnLatency = TRUE;
constexpr gint kUdpSocketBufferBytes = 2 * 1024 * 1024;
constexpr gint kJitterBufferMode = 0;
constexpr gboolean kParserDisablePassthrough = FALSE;
constexpr guint kQueueMaxSizeBuffers = 3;
constexpr guint kQueueMaxSizeBytes = 0;
constexpr guint64 kQueueMaxSizeTime = 0;
constexpr gint kQueueLeaky = 2;
constexpr gboolean kSinkQos = FALSE;
constexpr gint64 kSinkMaxLateness = -1;
constexpr gboolean kSinkAsync = FALSE;

const char* gstStateName(GstState state)
{
    switch (state) {
    case GST_STATE_VOID_PENDING:
        return "void-pending";
    case GST_STATE_NULL:
        return "null";
    case GST_STATE_READY:
        return "ready";
    case GST_STATE_PAUSED:
        return "paused";
    case GST_STATE_PLAYING:
        return "playing";
    default:
        return "unknown";
    }
}

QString gstObjectName(const GstObject* object)
{
    return (object != nullptr && GST_OBJECT_NAME(object) != nullptr)
        ? QString::fromUtf8(GST_OBJECT_NAME(object))
        : QStringLiteral("<null>");
}

QString gstFactoryName(GstElement* element)
{
    if (element == nullptr) {
        return QStringLiteral("<null>");
    }

    GstElementFactory* factory = gst_element_get_factory(element);
    return factory != nullptr
        ? QString::fromUtf8(gst_plugin_feature_get_name(GST_PLUGIN_FEATURE(factory)))
        : QStringLiteral("<no-factory>");
}

GParamSpec* gstPropertySpec(GstElement* element, const char* propertyName)
{
    return element != nullptr && propertyName != nullptr && G_OBJECT_GET_CLASS(element) != nullptr
        ? g_object_class_find_property(G_OBJECT_GET_CLASS(element), propertyName)
        : nullptr;
}

bool hasGstProperty(GstElement* element, const char* propertyName)
{
    return gstPropertySpec(element, propertyName) != nullptr;
}

void logMissingProperty(const QString& context, GstElement* element, const char* propertyName)
{
    qCInfo(GStreamLog).noquote() << "[GstVideoReceiver]" << context
                                    << "name=" << (element != nullptr ? gstObjectName(GST_OBJECT(element)) : QStringLiteral("<null>"))
                                    << "factory=" << gstFactoryName(element)
                                    << "missing-property=" << QString::fromUtf8(propertyName);
}

void setGstIntegralProperty(const QString& context, GstElement* element, const char* propertyName, qint64 value)
{
    GParamSpec* property = gstPropertySpec(element, propertyName);
    if (property == nullptr) {
        logMissingProperty(context, element, propertyName);
        return;
    }

    GValue gvalue = G_VALUE_INIT;
    g_value_init(&gvalue, property->value_type);

    const GType fundamentalType = G_TYPE_FUNDAMENTAL(property->value_type);
    switch (fundamentalType) {
    case G_TYPE_BOOLEAN:
        g_value_set_boolean(&gvalue, value != 0);
        break;
    case G_TYPE_INT:
        g_value_set_int(&gvalue, static_cast<gint>(value));
        break;
    case G_TYPE_UINT:
        g_value_set_uint(&gvalue, static_cast<guint>(value));
        break;
    case G_TYPE_INT64:
        g_value_set_int64(&gvalue, static_cast<gint64>(value));
        break;
    case G_TYPE_UINT64:
        g_value_set_uint64(&gvalue, static_cast<guint64>(value));
        break;
    case G_TYPE_ENUM:
        g_value_set_enum(&gvalue, static_cast<gint>(value));
        break;
    default:
        qCInfo(GStreamLog).noquote() << "[GstVideoReceiver]" << context
                                        << "name=" << gstObjectName(GST_OBJECT(element))
                                        << "factory=" << gstFactoryName(element)
                                        << "unsupported-property-type=" << QString::fromUtf8(propertyName)
                                        << "type=" << QString::fromUtf8(g_type_name(property->value_type));
        g_value_unset(&gvalue);
        return;
    }

    g_object_set_property(G_OBJECT(element), propertyName, &gvalue);
    g_value_unset(&gvalue);

    qCInfo(GStreamLog).noquote() << "[GstVideoReceiver]" << context
                                    << "name=" << gstObjectName(GST_OBJECT(element))
                                    << "factory=" << gstFactoryName(element)
                                    << QString::fromUtf8(propertyName) + "=" << value;
}

void setGstUIntProperty(const QString& context, GstElement* element, const char* propertyName, guint value)
{
    setGstIntegralProperty(context, element, propertyName, value);
}

void setGstIntProperty(const QString& context, GstElement* element, const char* propertyName, gint value)
{
    setGstIntegralProperty(context, element, propertyName, value);
}

void setGstBoolProperty(const QString& context, GstElement* element, const char* propertyName, gboolean value)
{
    setGstIntegralProperty(context, element, propertyName, value ? 1 : 0);
}

void setGstRtspTransportProperty(const QString& context, GstElement* element, GstRTSPLowerTrans transport)
{
    if (!hasGstProperty(element, "protocols")) {
        logMissingProperty(context, element, "protocols");
        return;
    }

    g_object_set(G_OBJECT(element), "protocols", transport, nullptr);
    qCInfo(GStreamLog).noquote() << "[GstVideoReceiver]" << context
                                    << "name=" << gstObjectName(GST_OBJECT(element))
                                    << "factory=" << gstFactoryName(element)
                                    << "protocols=udp";
}

void configureRtspUdpRobustness(GstElement* element, const QString& context)
{
    const QString factoryName = gstFactoryName(element);
    if (factoryName == QStringLiteral("rtspsrc")) {
        setGstUIntProperty(context, element, "latency", kRtspUdpLatencyMs);
        setGstBoolProperty(context, element, "drop-on-latency", kRtspDropOnLatency);
        setGstRtspTransportProperty(context, element, GST_RTSP_LOWER_TRANS_UDP);
        setGstBoolProperty(context, element, "udp-reconnect", TRUE);
        setGstUIntProperty(context, element, "timeout", kRtspUdpReconnectTimeoutUs);
        setGstUIntProperty(context, element, "udp-buffer-size", kUdpSocketBufferBytes);
    } else if (factoryName == QStringLiteral("rtpjitterbuffer")) {
        setGstUIntProperty(context, element, "latency", kRtspUdpLatencyMs);
        setGstBoolProperty(context, element, "drop-on-latency", kRtspDropOnLatency);
        setGstBoolProperty(context, element, "do-lost", TRUE);
        setGstBoolProperty(context, element, "do-retransmission", FALSE);
        setGstIntProperty(context, element, "mode", kJitterBufferMode);
        setGstBoolProperty(context, element, "post-drop-messages", TRUE);
    } else if (factoryName == QStringLiteral("udpsrc")) {
        setGstIntProperty(context, element, "buffer-size", kUdpSocketBufferBytes);
    }
}

void configureQueueProfile(GstElement* element, const QString& context)
{
    if (element == nullptr || gstFactoryName(element) != QStringLiteral("queue")) {
        return;
    }

    setGstUIntProperty(context, element, "max-size-buffers", kQueueMaxSizeBuffers);
    setGstUIntProperty(context, element, "max-size-bytes", kQueueMaxSizeBytes);
    setGstIntegralProperty(context, element, "max-size-time", kQueueMaxSizeTime);
    setGstIntProperty(context, element, "leaky", kQueueLeaky);
}

void configureVideoSinkProfile(GstElement* element, const QString& context)
{
    const QString factoryName = gstFactoryName(element);
    if (factoryName != QStringLiteral("qgcvideosinkbin") &&
        factoryName != QStringLiteral("qmlglsink") &&
        factoryName != QStringLiteral("glimagesink")) {
        return;
    }

    setGstBoolProperty(context, element, "sync", FALSE);
    setGstBoolProperty(context, element, "qos", kSinkQos);
    setGstIntegralProperty(context, element, "max-lateness", kSinkMaxLateness);
    setGstBoolProperty(context, element, "async", kSinkAsync);
    setGstBoolProperty(context, element, "force-aspect-ratio", TRUE);
}

void configureStartupParserHints(GstElement* element)
{
    if (element == nullptr || gstFactoryName(element) != QStringLiteral("h264parse")) {
        return;
    }

    GObjectClass* klass = G_OBJECT_GET_CLASS(element);
    if (klass == nullptr) {
        return;
    }

    if (g_object_class_find_property(klass, "config-interval") != nullptr) {
        g_object_set(element, "config-interval", -1, nullptr);
    }

    if (g_object_class_find_property(klass, "disable-passthrough") != nullptr) {
        g_object_set(element, "disable-passthrough", kParserDisablePassthrough, nullptr);
    }
}

} // namespace

//-----------------------------------------------------------------------------
// Our pipeline look like this:
//
//              +-->queue-->_decoderValve[-->_decoder-->_videoSink]
//              |
// _source-->_tee
//              |
//              +-->queue-->_recorderValve[-->_fileSink]
//

GstVideoReceiver::GstVideoReceiver(QObject* parent)
    : VideoReceiver(parent)
    , _streaming(false)
    , _decoding(false)
    , _recording(false)
    , _removingDecoder(false)
    , _removingRecorder(false)
    , _source(nullptr)
    , _tee(nullptr)
    , _decoderValve(nullptr)
    , _recorderValve(nullptr)
    , _decoder(nullptr)
    , _videoSink(nullptr)
    , _fileSink(nullptr)
    , _pipeline(nullptr)
    , _lastSourceFrameTime(0)
    , _lastVideoFrameTime(0)
    , _resetVideoSink(true)
    , _videoSinkProbeId(0)
    , _udpReconnect_us(5000000)
    , _signalDepth(0)
    , _endOfStream(false)
{
    _slotHandler.start();
    connect(&_watchdogTimer, &QTimer::timeout, this, &GstVideoReceiver::_watchdog);
    _watchdogTimer.start(1000);
}

GstVideoReceiver::~GstVideoReceiver(void)
{
    //stop();
    _slotHandler.shutdown();
}

void
GstVideoReceiver::_logElementSummary(const char* context, GstElement* element) const
{
    if (element == nullptr) {
        qCInfo(GStreamLog).noquote() << "[GstVideoReceiver]" << context << "element=<null>";
        return;
    }

    GstState state = GST_STATE_NULL;
    GstState pending = GST_STATE_VOID_PENDING;
    gst_element_get_state(element, &state, &pending, 0);

    qCInfo(GStreamLog).noquote() << "[GstVideoReceiver]" << context
                                 << "name=" << gstObjectName(GST_OBJECT(element))
                                 << "factory=" << gstFactoryName(element)
                                 << "state=" << gstStateName(state)
                                 << "pending=" << gstStateName(pending);
}

void
GstVideoReceiver::_logElementProperty(const char* context, GstElement* element, const char* propertyName) const
{
    if (element == nullptr || propertyName == nullptr) {
        return;
    }

    GParamSpec* property = g_object_class_find_property(G_OBJECT_GET_CLASS(element), propertyName);
    if (property == nullptr) {
        return;
    }

    GValue value = G_VALUE_INIT;
    g_value_init(&value, property->value_type);
    g_object_get_property(G_OBJECT(element), propertyName, &value);

    gchar* valueStr = g_strdup_value_contents(&value);
    qCInfo(GStreamLog).noquote() << "[GstVideoReceiver]" << context
                                 << "name=" << gstObjectName(GST_OBJECT(element))
                                 << QString::fromUtf8(propertyName) + "="
                                 << (valueStr != nullptr ? QString::fromUtf8(valueStr) : QStringLiteral("<null>"));

    if (valueStr != nullptr) {
        g_free(valueStr);
    }

    g_value_unset(&value);
}

void
GstVideoReceiver::_logReceiverChecklistProperties(const char* context, GstElement* element) const
{
    if (element == nullptr || context == nullptr) {
        return;
    }

    const QString factoryName = gstFactoryName(element);
    const QByteArray contextPrefix = QByteArray(context) + "." + factoryName.toUtf8();
    const char* scopedContext = contextPrefix.constData();

    if (factoryName == QStringLiteral("rtspsrc")) {
        _logElementProperty(scopedContext, element, "latency");
        _logElementProperty(scopedContext, element, "drop-on-latency");
        _logElementProperty(scopedContext, element, "protocols");
        _logElementProperty(scopedContext, element, "udp-reconnect");
        _logElementProperty(scopedContext, element, "timeout");
        _logElementProperty(scopedContext, element, "udp-buffer-size");
    } else if (factoryName == QStringLiteral("udpsrc")) {
        _logElementProperty(scopedContext, element, "port");
        _logElementProperty(scopedContext, element, "address");
        _logElementProperty(scopedContext, element, "auto-multicast");
        _logElementProperty(scopedContext, element, "multicast-iface");
        _logElementProperty(scopedContext, element, "buffer-size");
        _logElementProperty(scopedContext, element, "caps");
    } else if (factoryName == QStringLiteral("rtpjitterbuffer")) {
        _logElementProperty(scopedContext, element, "latency");
        _logElementProperty(scopedContext, element, "drop-on-latency");
        _logElementProperty(scopedContext, element, "do-lost");
        _logElementProperty(scopedContext, element, "do-retransmission");
        _logElementProperty(scopedContext, element, "mode");
        _logElementProperty(scopedContext, element, "max-dropout-time");
        _logElementProperty(scopedContext, element, "max-misorder-time");
        _logElementProperty(scopedContext, element, "post-drop-messages");
        _logPadCaps((contextPrefix + ".src").constData(), element, "src");
    } else if (factoryName == QStringLiteral("rtph264depay") || factoryName == QStringLiteral("rtph265depay")) {
        _logElementProperty(scopedContext, element, "request-keyframe");
        _logElementProperty(scopedContext, element, "wait-for-keyframe");
        _logPadCaps((contextPrefix + ".src").constData(), element, "src");
    } else if (factoryName == QStringLiteral("h264parse") || factoryName == QStringLiteral("h265parse")) {
        _logElementProperty(scopedContext, element, "config-interval");
        _logElementProperty(scopedContext, element, "disable-passthrough");
        _logPadCaps((contextPrefix + ".src").constData(), element, "src");
    } else if (factoryName == QStringLiteral("capsfilter")) {
        _logElementProperty(scopedContext, element, "caps");
        _logPadCaps((contextPrefix + ".src").constData(), element, "src");
    } else if (factoryName == QStringLiteral("queue") || factoryName.endsWith(QStringLiteral("queue"))) {
        _logElementProperty(scopedContext, element, "max-size-buffers");
        _logElementProperty(scopedContext, element, "max-size-bytes");
        _logElementProperty(scopedContext, element, "max-size-time");
        _logElementProperty(scopedContext, element, "leaky");
    } else if (factoryName == QStringLiteral("qgcvideosinkbin") ||
               factoryName == QStringLiteral("qmlglsink") ||
               factoryName == QStringLiteral("glimagesink")) {
        _logElementProperty(scopedContext, element, "sync");
        _logElementProperty(scopedContext, element, "qos");
        _logElementProperty(scopedContext, element, "max-lateness");
        _logElementProperty(scopedContext, element, "async");
        _logElementProperty(scopedContext, element, "force-aspect-ratio");
    }
}

void
GstVideoReceiver::_logCaps(const char* context, GstCaps* caps) const
{
    if (caps == nullptr) {
        qCInfo(GStreamLog).noquote() << "[GstVideoReceiver]" << context << "caps=<null>";
        return;
    }

    gchar* capsStr = gst_caps_to_string(caps);
    qCInfo(GStreamLog).noquote() << "[GstVideoReceiver]" << context
                                 << "caps=" << (capsStr != nullptr ? QString::fromUtf8(capsStr) : QStringLiteral("<null>"));

    if (capsStr != nullptr) {
        g_free(capsStr);
    }
}

void
GstVideoReceiver::_logPadCaps(const char* context, GstElement* element, const char* padName) const
{
    if (element == nullptr || padName == nullptr) {
        return;
    }

    GstPad* pad = gst_element_get_static_pad(element, padName);
    if (pad == nullptr) {
        return;
    }

    GstCaps* caps = gst_pad_query_caps(pad, nullptr);
    const QString label = QStringLiteral("%1 name=%2 pad=%3")
                              .arg(QString::fromUtf8(context), gstObjectName(GST_OBJECT(element)), QString::fromUtf8(padName));
    _logCaps(label.toUtf8().constData(), caps);

    if (caps != nullptr) {
        gst_caps_unref(caps);
    }

    gst_object_unref(pad);
}

void
GstVideoReceiver::_logPipelineConfiguration(const char* context) const
{
    qCInfo(GStreamLog).noquote() << "[GstVideoReceiver]" << context
                                 << "uri=" << _uri
                                 << "timeout=" << _timeout
                                 << "buffer=" << _buffer
                                 << "udpReconnect_us=" << static_cast<qulonglong>(_udpReconnect_us)
                                 << "streaming=" << _streaming
                                 << "decoding=" << _decoding
                                 << "recording=" << _recording;

    _logElementSummary("pipeline", _pipeline);
    _logElementSummary("source", _source);
    _logElementSummary("tee", _tee);
    _logElementSummary("decoderValve", _decoderValve);
    _logElementSummary("decoder", _decoder);
    _logElementSummary("videoSink", _videoSink);
    _logElementSummary("recorderValve", _recorderValve);
    _logElementSummary("fileSink", _fileSink);

    _logElementProperty("pipeline", _pipeline, "message-forward");
    _logElementProperty("source", _source, "location");
    _logElementProperty("source", _source, "uri");
    _logElementProperty("source", _source, "port");
    _logElementProperty("source", _source, "host");
    _logElementProperty("source", _source, "latency");
    _logElementProperty("source", _source, "drop-on-latency");
    _logElementProperty("source", _source, "protocols");
    _logElementProperty("source", _source, "udp-reconnect");
    _logElementProperty("source", _source, "timeout");
    _logElementProperty("source", _source, "caps");
    _logElementProperty("decoderValve", _decoderValve, "drop");
    _logElementProperty("recorderValve", _recorderValve, "drop");
    _logElementProperty("videoSink", _videoSink, "sync");

    if (_pipeline != nullptr) {
        GstIterator* iterator = gst_bin_iterate_recurse(GST_BIN(_pipeline));
        if (iterator != nullptr) {
            GValue item = G_VALUE_INIT;
            while (gst_iterator_next(iterator, &item) == GST_ITERATOR_OK) {
                GstElement* element = GST_ELEMENT(g_value_get_object(&item));
                if (element != nullptr) {
                    const QString factoryName = gstFactoryName(element);
                    const QString name = gstObjectName(GST_OBJECT(element));
                    qCInfo(GStreamLog).noquote() << "[GstVideoReceiver]" << context
                                                 << "pipelineElement"
                                                 << "name=" << name
                                                 << "factory=" << factoryName;

                    if (factoryName == QStringLiteral("rtpjitterbuffer")) {
                        _logElementProperty("rtpjitterbuffer", element, "latency");
                        _logElementProperty("rtpjitterbuffer", element, "drop-on-latency");
                        _logElementProperty("rtpjitterbuffer", element, "mode");
                        _logPadCaps("rtpjitterbuffer.src", element, "src");
                    } else if (factoryName == QStringLiteral("parsebin")) {
                        _logPadCaps("parsebin.src", element, "src");
                    } else if (factoryName == QStringLiteral("decodebin3")) {
                        _logPadCaps("decodebin3.src", element, "src");
                    } else if (factoryName == QStringLiteral("udpsrc") || factoryName == QStringLiteral("rtspsrc")) {
                        _logPadCaps("source.src", element, "src");
                    }
                    _logReceiverChecklistProperties(context, element);
                }
                g_value_reset(&item);
            }
            gst_iterator_free(iterator);
        }
    }
}

void
GstVideoReceiver::start(const QString& uri, unsigned timeout, int buffer)
{
    if (_needDispatch()) {
        QString cachedUri = uri;
        _slotHandler.dispatch([this, cachedUri, timeout, buffer]() {
            start(cachedUri, timeout, buffer);
        });
        return;
    }

    if(_pipeline) {
        qCDebug(VideoReceiverLog) << "Already running!" << _uri;
        _dispatchSignal([this](){
            emit onStartComplete(STATUS_INVALID_STATE);
        });
        return;
    }

    if (uri.isEmpty()) {
        qCDebug(VideoReceiverLog) << "Failed because URI is not specified";
        _dispatchSignal([this](){
            emit onStartComplete(STATUS_INVALID_URL);
        });
        return;
    }

    _uri = uri;
    _timeout = timeout;
    _buffer = buffer;

    qCDebug(VideoReceiverLog) << "Starting" << _uri << ", buffer" << _buffer;

    _endOfStream = false;

    bool running    = false;
    bool pipelineUp = false;

    GstElement* decoderQueue = nullptr;
    GstElement* recorderQueue = nullptr;

    do {
        if((_tee = gst_element_factory_make("tee", nullptr)) == nullptr)  {
            qCCritical(VideoReceiverLog) << "gst_element_factory_make('tee') failed";
            break;
        }

        GstPad* pad;

        if ((pad = gst_element_get_static_pad(_tee, "sink")) == nullptr) {
            qCCritical(VideoReceiverLog) << "gst_element_get_static_pad() failed";
            break;
        }

        _lastSourceFrameTime = 0;

        _teeProbeId = gst_pad_add_probe(pad, GST_PAD_PROBE_TYPE_BUFFER, _teeProbe, this, nullptr);
        gst_object_unref(pad);
        pad = nullptr;

        if((decoderQueue = gst_element_factory_make("queue", nullptr)) == nullptr)  {
            qCCritical(VideoReceiverLog) << "gst_element_factory_make('queue') failed";
            break;
        }
        configureQueueProfile(decoderQueue, QStringLiteral("decoder-queue.configured"));

        if((_decoderValve = gst_element_factory_make("valve", nullptr)) == nullptr)  {
            qCCritical(VideoReceiverLog) << "gst_element_factory_make('valve') failed";
            break;
        }

        g_object_set(_decoderValve, "drop", TRUE, nullptr);

        if((recorderQueue = gst_element_factory_make("queue", nullptr)) == nullptr)  {
            qCCritical(VideoReceiverLog) << "gst_element_factory_make('queue') failed";
            break;
        }
        configureQueueProfile(recorderQueue, QStringLiteral("recorder-queue.configured"));

        if((_recorderValve = gst_element_factory_make("valve", nullptr)) == nullptr)  {
            qCCritical(VideoReceiverLog) << "gst_element_factory_make('valve') failed";
            break;
        }

        g_object_set(_recorderValve, "drop", TRUE, nullptr);

        if ((_pipeline = gst_pipeline_new("receiver")) == nullptr) {
            qCCritical(VideoReceiverLog) << "gst_pipeline_new() failed";
            break;
        }

        g_object_set(_pipeline, "message-forward", TRUE, nullptr);
        g_signal_connect(_pipeline, "deep-element-added", G_CALLBACK(_onDeepElementAdded), this);

        if ((_source = _makeSource(uri)) == nullptr) {
            qCCritical(VideoReceiverLog) << "_makeSource() failed";
            break;
        }

        gst_bin_add_many(GST_BIN(_pipeline), _source, _tee, decoderQueue, _decoderValve, recorderQueue, _recorderValve, nullptr);

        pipelineUp = true;

        GstPad* srcPad = nullptr;

        GstIterator* it;

        if ((it = gst_element_iterate_src_pads(_source)) != nullptr) {
            GValue vpad = G_VALUE_INIT;

            if (gst_iterator_next(it, &vpad) == GST_ITERATOR_OK) {
                srcPad = GST_PAD(g_value_get_object(&vpad));
                gst_object_ref(srcPad);
                g_value_reset(&vpad);
            }

            gst_iterator_free(it);
            it = nullptr;
        }

        if (srcPad != nullptr) {
            _onNewSourcePad(srcPad);
            gst_object_unref(srcPad);
            srcPad = nullptr;
        } else {
            g_signal_connect(_source, "pad-added", G_CALLBACK(_onNewPad), this);
        }

        if(!gst_element_link_many(_tee, decoderQueue, _decoderValve, nullptr)) {
            qCCritical(VideoReceiverLog) << "Unable to link decoder queue";
            break;
        }

        if(!gst_element_link_many(_tee, recorderQueue, _recorderValve, nullptr)) {
            qCCritical(VideoReceiverLog) << "Unable to link recorder queue";
            break;
        }

        GstBus* bus = nullptr;

        if ((bus = gst_pipeline_get_bus(GST_PIPELINE(_pipeline))) != nullptr) {
            gst_bus_enable_sync_message_emission(bus);
            g_signal_connect(bus, "sync-message", G_CALLBACK(_onBusMessage), this);
            gst_object_unref(bus);
            bus = nullptr;
        }

        GST_DEBUG_BIN_TO_DOT_FILE(GST_BIN(_pipeline), GST_DEBUG_GRAPH_SHOW_ALL, "pipeline-initial");
        running = gst_element_set_state(_pipeline, GST_STATE_PLAYING) != GST_STATE_CHANGE_FAILURE;
    } while(0);

    if (!running) {
        qCCritical(VideoReceiverLog) << "Failed";

        // In newer versions, the pipeline will clean up all references that are added to it
        if (_pipeline != nullptr) {
            gst_element_set_state(_pipeline, GST_STATE_NULL);
            gst_object_unref(_pipeline);
            _pipeline = nullptr;
        }

        // If we failed before adding items to the pipeline, then clean up
        if (!pipelineUp) {
            if (_recorderValve != nullptr) {
                gst_object_unref(_recorderValve);
                _recorderValve = nullptr;
            }

            if (recorderQueue != nullptr) {
                gst_object_unref(recorderQueue);
                recorderQueue = nullptr;
            }

            if (_decoderValve != nullptr) {
                gst_object_unref(_decoderValve);
                _decoderValve = nullptr;
            }

            if (decoderQueue != nullptr) {
                gst_object_unref(decoderQueue);
                decoderQueue = nullptr;
            }

            if (_tee != nullptr) {
                gst_object_unref(_tee);
                _tee = nullptr;
            }

            if (_source != nullptr) {
                gst_object_unref(_source);
                _source = nullptr;
            }
        }

        _dispatchSignal([this](){
            emit onStartComplete(STATUS_FAIL);
        });
    } else {
        GST_DEBUG_BIN_TO_DOT_FILE(GST_BIN(_pipeline), GST_DEBUG_GRAPH_SHOW_ALL, "pipeline-started");
        qCDebug(VideoReceiverLog) << "Started" << _uri;

        _dispatchSignal([this](){
            emit onStartComplete(STATUS_OK);
        });
    }
}

void
GstVideoReceiver::stop(void)
{
    if (_needDispatch()) {
        _slotHandler.dispatch([this]() {
            stop();
        });
        return;
    }

    if (_uri.isEmpty()) {
        qCInfo(VideoReceiverLog) << "Stop called on empty URI";
        return;
    }

    qCDebug(VideoReceiverLog) << "Stopping" << _uri;

    if (_teeProbeId != 0) {
        GstPad* sinkpad;
        if ((sinkpad = gst_element_get_static_pad(_tee, "sink")) != nullptr) {
            gst_pad_remove_probe(sinkpad, _teeProbeId);
            sinkpad = nullptr;
        }
        _teeProbeId = 0;
    }

    if (_pipeline != nullptr) {
        GstBus* bus;

        if ((bus = gst_pipeline_get_bus(GST_PIPELINE(_pipeline))) != nullptr) {
            gst_bus_disable_sync_message_emission(bus);

            g_signal_handlers_disconnect_by_data(bus, this);

            gboolean recordingValveClosed = TRUE;

            g_object_get(_recorderValve, "drop", &recordingValveClosed, nullptr);

            if (recordingValveClosed == FALSE) {
                gst_element_send_event(_pipeline, gst_event_new_eos());

                GstMessage* msg;

                if((msg = gst_bus_timed_pop_filtered(bus, GST_CLOCK_TIME_NONE, (GstMessageType)(GST_MESSAGE_EOS|GST_MESSAGE_ERROR))) != nullptr) {
                    if(GST_MESSAGE_TYPE(msg) == GST_MESSAGE_ERROR) {
                        qCCritical(VideoReceiverLog) << "Error stopping pipeline!";
                    } else if(GST_MESSAGE_TYPE(msg) == GST_MESSAGE_EOS) {
                        qCDebug(VideoReceiverLog) << "End of stream received!";
                    }

                    gst_message_unref(msg);
                    msg = nullptr;
                } else {
                    qCCritical(VideoReceiverLog) << "gst_bus_timed_pop_filtered() failed";
                }
            }

            gst_object_unref(bus);
            bus = nullptr;
        } else {
            qCCritical(VideoReceiverLog) << "gst_pipeline_get_bus() failed";
        }

        gst_element_set_state(_pipeline, GST_STATE_NULL);

        // FIXME: check if branch is connected and remove all elements from branch
        if (_fileSink != nullptr) {
           _shutdownRecordingBranch();
        }

        if (_videoSink != nullptr) {
            _shutdownDecodingBranch();
        }

        GST_DEBUG_BIN_TO_DOT_FILE(GST_BIN(_pipeline), GST_DEBUG_GRAPH_SHOW_ALL, "pipeline-stopped");

        gst_object_unref(_pipeline);
        _pipeline = nullptr;

        _recorderValve = nullptr;
        _decoderValve = nullptr;
        _tee = nullptr;
        _source = nullptr;

        _lastSourceFrameTime = 0;

        if (_streaming) {
            _streaming = false;
            qCDebug(VideoReceiverLog) << "Streaming stopped" << _uri;
            _dispatchSignal([this](){
                emit streamingChanged(_streaming);
            });
        } else {
            qCDebug(VideoReceiverLog) << "Streaming did not start" << _uri;
        }
    }

    qCDebug(VideoReceiverLog) << "Stopped" << _uri;

    _dispatchSignal([this](){
        emit onStopComplete(STATUS_OK);
    });
}

void
GstVideoReceiver::startDecoding(void* sink)
{
    if (sink == nullptr) {
        qCCritical(VideoReceiverLog) << "VideoSink is NULL" << _uri;
        return;
    }

    if (_needDispatch()) {
        GstElement* videoSink = GST_ELEMENT(sink);
        //gst_object_ref(videoSink);
        _slotHandler.dispatch([this, videoSink]() mutable {
            startDecoding(videoSink);
          //  gst_object_unref(videoSink);
        });
        return;
    }

    qCDebug(VideoReceiverLog) << "Starting decoding" << _uri;

    if (_pipeline == nullptr) {
        if (_videoSink != nullptr) {
            gst_object_unref(_videoSink);
            _videoSink = nullptr;
        }
    }

    GstElement* videoSink = GST_ELEMENT(sink);

    if(_videoSink != nullptr || _decoding) {
        qCDebug(VideoReceiverLog) << "Already decoding!" << _uri;
        _dispatchSignal([this](){
            emit onStartDecodingComplete(STATUS_INVALID_STATE);
        });
        return;
    }

    GstPad* pad;

    if ((pad = gst_element_get_static_pad(videoSink, "sink")) == nullptr) {
        qCCritical(VideoReceiverLog) << "Unable to find sink pad of video sink" << _uri;
        _dispatchSignal([this](){
            emit onStartDecodingComplete(STATUS_FAIL);
        });
        return;
    }

    _lastVideoFrameTime = 0;
    _resetVideoSink = true;

    _videoSinkProbeId = gst_pad_add_probe(pad, GST_PAD_PROBE_TYPE_BUFFER, _videoSinkProbe, this, nullptr);
    gst_object_unref(pad);
    pad = nullptr;

    _videoSink = videoSink;
    gst_object_ref(_videoSink);

    _removingDecoder = false;

    if (!_streaming) {
        _dispatchSignal([this](){
            emit onStartDecodingComplete(STATUS_OK);
        });
        return;
    }

    if (!_addDecoder(_decoderValve)) {
        qCCritical(VideoReceiverLog) << "_addDecoder() failed" << _uri;
        _dispatchSignal([this](){
            emit onStartDecodingComplete(STATUS_FAIL);
        });
        return;
    }

    g_object_set(_decoderValve, "drop", FALSE, nullptr);

    qCDebug(VideoReceiverLog) << "Decoding started" << _uri;

    _dispatchSignal([this](){
        emit onStartDecodingComplete(STATUS_OK);
    });
}

void
GstVideoReceiver::stopDecoding(void)
{
    if (_needDispatch()) {
        _slotHandler.dispatch([this]() {
            stopDecoding();
        });
        return;
    }

    qCDebug(VideoReceiverLog) << "Stopping decoding" << _uri;

    // exit immediately if we are not decoding
    if (_pipeline == nullptr || !_decoding) {
        qCDebug(VideoReceiverLog) << "Not decoding!" << _uri;
        _dispatchSignal([this](){
            emit onStopDecodingComplete(STATUS_INVALID_STATE);
        });
        return;
    }

    g_object_set(_decoderValve, "drop", TRUE, nullptr);

    _removingDecoder = true;

    bool ret = _unlinkBranch(_decoderValve);

    // FIXME: AV: it is much better to emit onStopDecodingComplete() after decoding is really stopped
    // (which happens later due to async design) but as for now it is also not so bad...
    _dispatchSignal([this, ret](){
        emit onStopDecodingComplete(ret ? STATUS_OK : STATUS_FAIL);
    });
}

void
GstVideoReceiver::startRecording(const QString& videoFile, FILE_FORMAT format)
{
    if (_needDispatch()) {
        QString cachedVideoFile = videoFile;
        _slotHandler.dispatch([this, cachedVideoFile, format]() {
            startRecording(cachedVideoFile, format);
        });
        return;
    }

    qCDebug(VideoReceiverLog) << "Starting recording" << _uri;

    if (_pipeline == nullptr) {
        qCDebug(VideoReceiverLog) << "Streaming is not active!" << _uri;
        _dispatchSignal([this](){
            emit onStartRecordingComplete(STATUS_INVALID_STATE);
        });
        return;
    }

    if (_recording) {
        qCDebug(VideoReceiverLog) << "Already recording!" << _uri;
        _dispatchSignal([this](){
            emit onStartRecordingComplete(STATUS_INVALID_STATE);
        });
        return;
    }

    qCDebug(VideoReceiverLog) << "New video file:" << videoFile <<  "" << _uri;

    if ((_fileSink = _makeFileSink(videoFile, format)) == nullptr) {
        qCCritical(VideoReceiverLog) << "_makeFileSink() failed" << _uri;
        _dispatchSignal([this](){
            emit onStartRecordingComplete(STATUS_FAIL);
        });
        return;
    }

    _removingRecorder = false;

    gst_object_ref(_fileSink);

    gst_bin_add(GST_BIN(_pipeline), _fileSink);

    if (!gst_element_link(_recorderValve, _fileSink)) {
        qCCritical(VideoReceiverLog) << "Failed to link valve and file sink" << _uri;
        _dispatchSignal([this](){
            emit onStartRecordingComplete(STATUS_FAIL);
        });
        return;
    }

    gst_element_sync_state_with_parent(_fileSink);

    GST_DEBUG_BIN_TO_DOT_FILE(GST_BIN(_pipeline), GST_DEBUG_GRAPH_SHOW_ALL, "pipeline-with-filesink");

    // Install a probe on the recording branch to drop buffers until we hit our first keyframe
    // When we hit our first keyframe, we can offset the timestamps appropriately according to the first keyframe time
    // This will ensure the first frame is a keyframe at t=0, and decoding can begin immediately on playback
    GstPad* probepad;

    if ((probepad  = gst_element_get_static_pad(_recorderValve, "src")) == nullptr) {
        qCCritical(VideoReceiverLog) << "gst_element_get_static_pad() failed" << _uri;
        _dispatchSignal([this](){
            emit onStartRecordingComplete(STATUS_FAIL);
        });
        return;
    }

    gst_pad_add_probe(probepad, GST_PAD_PROBE_TYPE_BUFFER, _keyframeWatch, this, nullptr); // to drop the buffers until key frame is received
    gst_object_unref(probepad);
    probepad = nullptr;

    g_object_set(_recorderValve, "drop", FALSE, nullptr);

    _recording = true;
    qCDebug(VideoReceiverLog) << "Recording started" << _uri;
    _dispatchSignal([this](){
        emit onStartRecordingComplete(STATUS_OK);
        emit recordingChanged(_recording);
    });
}

//-----------------------------------------------------------------------------
void
GstVideoReceiver::stopRecording(void)
{
    if (_needDispatch()) {
        _slotHandler.dispatch([this]() {
            stopRecording();
        });
        return;
    }

    qCDebug(VideoReceiverLog) << "Stopping recording" << _uri;

    // exit immediately if we are not recording
    if (_pipeline == nullptr || !_recording) {
        qCDebug(VideoReceiverLog) << "Not recording!" << _uri;
        _dispatchSignal([this](){
            emit onStopRecordingComplete(STATUS_INVALID_STATE);
        });
        return;
    }

    g_object_set(_recorderValve, "drop", TRUE, nullptr);

    _removingRecorder = true;

    bool ret = _unlinkBranch(_recorderValve);

    // FIXME: AV: it is much better to emit onStopRecordingComplete() after recording is really stopped
    // (which happens later due to async design) but as for now it is also not so bad...
    _dispatchSignal([this, ret](){
        emit onStopRecordingComplete(ret ? STATUS_OK : STATUS_FAIL);
    });
}

void
GstVideoReceiver::takeScreenshot(const QString& imageFile)
{
    if (_needDispatch()) {
        QString cachedImageFile = imageFile;
        _slotHandler.dispatch([this, cachedImageFile]() {
            takeScreenshot(cachedImageFile);
        });
        return;
    }

    // FIXME: AV: record screenshot here
    _dispatchSignal([this](){
        emit onTakeScreenshotComplete(STATUS_NOT_IMPLEMENTED);
    });
}

const char* GstVideoReceiver::_kFileMux[FILE_FORMAT_MAX - FILE_FORMAT_MIN] = {
    "matroskamux",
    "qtmux",
    "mp4mux"
};

void
GstVideoReceiver::_watchdog(void)
{

    // timeout이 0이면 watchdog 끔
    if (_timeout == 0) {
        return;
    }

    _slotHandler.dispatch([this](){
        if(_pipeline == nullptr) {
            return;
        }

        const qint64 now = QDateTime::currentSecsSinceEpoch();

        if (_lastSourceFrameTime == 0) {
            _lastSourceFrameTime = now;
        }

        if (now - _lastSourceFrameTime > _timeout) {
            qCDebug(VideoReceiverLog) << "Stream timeout, no frames for " << now - _lastSourceFrameTime << "" << _uri;
            _dispatchSignal([this](){
                emit timeout();
            });
            stop();
        }

        if (_decoding && !_removingDecoder) {
            if (_lastVideoFrameTime == 0) {
                _lastVideoFrameTime = now;
            }

            if (now - _lastVideoFrameTime > _timeout * 2) {
                qCDebug(VideoReceiverLog) << "Video decoder timeout, no frames for " << now - _lastVideoFrameTime << " " << _uri;
                _dispatchSignal([this](){
                    emit timeout();
                });
                stop();
            }
        }
    });
}

void
GstVideoReceiver::_handleEOS(void)
{
    if(_pipeline == nullptr) {
        return;
    }

    if (_endOfStream) {
        stop();
    } else {
        if(_decoding && _removingDecoder) {
            _shutdownDecodingBranch();
        } else if(_recording && _removingRecorder) {
            _shutdownRecordingBranch();
        } /*else {
            qCWarning(VideoReceiverLog) << "Unexpected EOS!";
            stop();
        }*/
    }
}

gboolean
GstVideoReceiver::_filterParserCaps(GstElement* bin, GstPad* pad, GstElement* element, GstQuery* query, gpointer data)
{
    Q_UNUSED(bin)
    Q_UNUSED(pad)
    Q_UNUSED(element)
    Q_UNUSED(data)

    if (GST_QUERY_TYPE(query) != GST_QUERY_CAPS) {
        return FALSE;
    }

    GstCaps* srcCaps;

    gst_query_parse_caps(query, &srcCaps);

    if (srcCaps == nullptr || gst_caps_is_any(srcCaps)) {
        return FALSE;
    }

    GstCaps* sinkCaps = nullptr;

    GstCaps* filter;

    GstStructure* structure;

    structure = gst_caps_get_structure(srcCaps, 0);
    if(gst_structure_has_name(structure, "video/x-h265")){
        filter = gst_caps_from_string("video/x-h265");
        if (gst_caps_can_intersect(srcCaps, filter)) {
            sinkCaps = gst_caps_from_string("video/x-h265,stream-format=hvc1");
        }
        gst_caps_unref(filter);
        filter = nullptr;
    } else if(gst_structure_has_name(structure, "video/x-h264")){
        filter = gst_caps_from_string("video/x-h264");
        if (gst_caps_can_intersect(srcCaps, filter)) {
            sinkCaps = gst_caps_from_string("video/x-h264,stream-format=avc");
        }
        gst_caps_unref(filter);
        filter = nullptr;
    }

    if (sinkCaps == nullptr) {
        return FALSE;
    }

    gst_query_set_caps_result(query, sinkCaps);

    gst_caps_unref(sinkCaps);
    sinkCaps = nullptr;

    return TRUE;
}

GstElement*
GstVideoReceiver::_makeSource(const QString& uri)
{
    if (uri.isEmpty()) {
        qCCritical(VideoReceiverLog) << "Failed because URI is not specified";
        return nullptr;
    }

    bool isTaisync  = uri.contains("tsusb://",  Qt::CaseInsensitive);
    bool isUdp264   = uri.contains("udp://",    Qt::CaseInsensitive);
    bool isRtsp     = uri.contains("rtsp://",   Qt::CaseInsensitive);
    bool isUdp265   = uri.contains("udp265://", Qt::CaseInsensitive);
    bool isTcpMPEGTS= uri.contains("tcp://",    Qt::CaseInsensitive);
    bool isUdpMPEGTS= uri.contains("mpegts://", Qt::CaseInsensitive);

    GstElement* source  = nullptr;
    GstElement* buffer  = nullptr;
    GstElement* tsdemux = nullptr;
    GstElement* parser  = nullptr;
    GstElement* bin     = nullptr;
    GstElement* srcbin  = nullptr;

    do {
        QUrl url(uri);

        if(isTcpMPEGTS) {
            if ((source = gst_element_factory_make("tcpclientsrc", "source")) != nullptr) {
                g_object_set(static_cast<gpointer>(source), "host", qPrintable(url.host()), "port", url.port(), nullptr);
            }
        } else if (isRtsp) {
            if ((source = gst_element_factory_make("rtspsrc", "source")) != nullptr) {
                g_object_set(static_cast<gpointer>(source), "location", qPrintable(uri), NULL);
                configureRtspUdpRobustness(source, QStringLiteral("rtspsrc.configured"));
                g_signal_connect(source, "new-manager", G_CALLBACK(_onRtspNewManager), this);
                if (GST_IS_CHILD_PROXY(source)) {
                    g_signal_connect(source, "child-added", G_CALLBACK(_onChildAdded), this);
                }
            }
        } else if(isUdp264 || isUdp265 || isUdpMPEGTS || isTaisync) {
            if ((source = gst_element_factory_make("udpsrc", "source")) != nullptr) {
                g_object_set(static_cast<gpointer>(source), "uri", QString("udp://%1:%2").arg(qPrintable(url.host()), QString::number(url.port())).toUtf8().data(), nullptr);
                configureRtspUdpRobustness(source, QStringLiteral("udpsrc.configured"));

                GstCaps* caps = nullptr;

                if(isUdp264) {
                    if ((caps = gst_caps_from_string("application/x-rtp, media=(string)video, clock-rate=(int)90000, encoding-name=(string)H264")) == nullptr) {
                        qCCritical(VideoReceiverLog) << "gst_caps_from_string() failed";
                        break;
                    }
                } else if (isUdp265) {
                    if ((caps = gst_caps_from_string("application/x-rtp, media=(string)video, clock-rate=(int)90000, encoding-name=(string)H265")) == nullptr) {
                        qCCritical(VideoReceiverLog) << "gst_caps_from_string() failed";
                        break;
                    }
                }

                if (caps != nullptr) {
                    g_object_set(static_cast<gpointer>(source), "caps", caps, nullptr);
                    _logCaps("udpsrc.caps-configured", caps);
                    gst_caps_unref(caps);
                    caps = nullptr;
                }
            }
        } else {
            qCDebug(VideoReceiverLog) << "URI is not recognized";
        }

        if (!source) {
            qCCritical(VideoReceiverLog) << "gst_element_factory_make() for data source failed";
            break;
        }

        if ((bin = gst_bin_new("sourcebin")) == nullptr) {
            qCCritical(VideoReceiverLog) << "gst_bin_new('sourcebin') failed";
            break;
        }

        if ((parser = gst_element_factory_make("parsebin", "parser")) == nullptr) {
            qCCritical(VideoReceiverLog) << "gst_element_factory_make('parsebin') failed";
            break;
        }

        // A30TR/Viewpro RTSP streams can fail caps negotiation with this parser hook enabled.
        // Keep parsebin default autoplug behavior to match the known-good legacy build.
        //g_signal_connect(parser, "autoplug-query", G_CALLBACK(_filterParserCaps), nullptr);
        if (GST_IS_BIN(parser)) {
            g_signal_connect(parser, "deep-element-added", G_CALLBACK(_onDeepElementAdded), this);
        }
        if (GST_IS_CHILD_PROXY(parser)) {
            g_signal_connect(parser, "child-added", G_CALLBACK(_onChildAdded), this);
        }

        gst_bin_add_many(GST_BIN(bin), source, parser, nullptr);

        // FIXME: AV: Android does not determine MPEG2-TS via parsebin - have to explicitly state which demux to use
        // FIXME: AV: tsdemux handling is a bit ugly - let's try to find elegant solution for that later
        if (isTcpMPEGTS || isUdpMPEGTS) {
            if ((tsdemux = gst_element_factory_make("tsdemux", nullptr)) == nullptr) {
                qCCritical(VideoReceiverLog) << "gst_element_factory_make('tsdemux') failed";
                break;
            }

            gst_bin_add(GST_BIN(bin), tsdemux);

            if (!gst_element_link(source, tsdemux)) {
                qCCritical(VideoReceiverLog) << "gst_element_link() failed";
                break;
            }

            source = tsdemux;
            tsdemux = nullptr;
        }

        int probeRes = 0;

        gst_element_foreach_src_pad(source, _padProbe, &probeRes);

        if (probeRes & 1) {
            if (probeRes & 2 && _buffer >= 0) {
                if ((buffer = gst_element_factory_make("rtpjitterbuffer", nullptr)) == nullptr) {
                    qCCritical(VideoReceiverLog) << "gst_element_factory_make('rtpjitterbuffer') failed";
                    break;
                }
                configureRtspUdpRobustness(buffer, QStringLiteral("rtpjitterbuffer.configured"));

                gst_bin_add(GST_BIN(bin), buffer);

                if (!gst_element_link_many(source, buffer, parser, nullptr)) {
                    qCCritical(VideoReceiverLog) << "gst_element_link() failed";
                    break;
                }
            } else {
                if (!gst_element_link(source, parser)) {
                    qCCritical(VideoReceiverLog) << "gst_element_link() failed";
                    break;
                }
            }
        } else {
            g_signal_connect(source, "pad-added", G_CALLBACK(_linkPad), parser);
        }

        g_signal_connect(parser, "pad-added", G_CALLBACK(_wrapWithGhostPad), nullptr);

        source = tsdemux = buffer = parser = nullptr;

        srcbin = bin;
        bin = nullptr;
    } while(0);

    if (bin != nullptr) {
        gst_object_unref(bin);
        bin = nullptr;
    }

    if (parser != nullptr) {
        gst_object_unref(parser);
        parser = nullptr;
    }

    if (tsdemux != nullptr) {
        gst_object_unref(tsdemux);
        tsdemux = nullptr;
    }

    if (buffer != nullptr) {
        gst_object_unref(buffer);
        buffer = nullptr;
    }

    if (source != nullptr) {
        gst_object_unref(source);
        source = nullptr;
    }

    return srcbin;
}

GstElement*
GstVideoReceiver::_makeDecoder(GstCaps* caps, GstElement* videoSink)
{
    Q_UNUSED(caps)
    Q_UNUSED(videoSink)
    GstElement* decoder = nullptr;

    do {
        if ((decoder = gst_element_factory_make("decodebin3", nullptr)) == nullptr) {
            qCCritical(VideoReceiverLog) << "gst_element_factory_make('decodebin3') failed";
            break;
        }
        if (GST_IS_BIN(decoder)) {
            g_signal_connect(decoder, "deep-element-added", G_CALLBACK(_onDeepElementAdded), this);
        }
        if (GST_IS_CHILD_PROXY(decoder)) {
            g_signal_connect(decoder, "child-added", G_CALLBACK(_onChildAdded), this);
        }
    } while(0);

    return decoder;
}

GstElement*
GstVideoReceiver::_makeFileSink(const QString& videoFile, FILE_FORMAT format)
{
    GstElement* fileSink = nullptr;
    GstElement* mux = nullptr;
    GstElement* sink = nullptr;
    GstElement* bin = nullptr;
    bool releaseElements = true;

    do{
        if (format < FILE_FORMAT_MIN || format >= FILE_FORMAT_MAX) {
            qCCritical(VideoReceiverLog) << "Unsupported file format";
            break;
        }

        if ((mux = gst_element_factory_make(_kFileMux[format - FILE_FORMAT_MIN], nullptr)) == nullptr) {
            qCCritical(VideoReceiverLog) << "gst_element_factory_make('" << _kFileMux[format - FILE_FORMAT_MIN] << "') failed";
            break;
        }

        if ((sink = gst_element_factory_make("filesink", nullptr)) == nullptr) {
            qCCritical(VideoReceiverLog) << "gst_element_factory_make('filesink') failed";
            break;
        }

        g_object_set(static_cast<gpointer>(sink), "location", qPrintable(videoFile), nullptr);

        if ((bin = gst_bin_new("sinkbin")) == nullptr) {
            qCCritical(VideoReceiverLog) << "gst_bin_new('sinkbin') failed";
            break;
        }

        GstPadTemplate* padTemplate;

        if ((padTemplate = gst_element_class_get_pad_template(GST_ELEMENT_GET_CLASS(mux), "video_%u")) == nullptr) {
            qCCritical(VideoReceiverLog) << "gst_element_class_get_pad_template(mux) failed";
            break;
        }

        // FIXME: AV: pad handling is potentially leaking (and other similar places too!)
        GstPad* pad;

        if ((pad = gst_element_request_pad(mux, padTemplate, nullptr, nullptr)) == nullptr) {
            qCCritical(VideoReceiverLog) << "gst_element_request_pad(mux) failed";
            break;
        }

        gst_bin_add_many(GST_BIN(bin), mux, sink, nullptr);

        releaseElements = false;

        GstPad* ghostpad = gst_ghost_pad_new("sink", pad);

        gst_element_add_pad(bin, ghostpad);

        gst_object_unref(pad);
        pad = nullptr;

        if (!gst_element_link(mux, sink)) {
            qCCritical(VideoReceiverLog) << "gst_element_link() failed";
            break;
        }

        fileSink = bin;
        bin = nullptr;
    } while(0);

    if (releaseElements) {
        if (sink != nullptr) {
            gst_object_unref(sink);
            sink = nullptr;
        }

        if (mux != nullptr) {
            gst_object_unref(mux);
            mux = nullptr;
        }
    }

    if (bin != nullptr) {
        gst_object_unref(bin);
        bin = nullptr;
    }

    return fileSink;
}

void
GstVideoReceiver::_onNewSourcePad(GstPad* pad)
{
    // FIXME: check for caps - if this is not video stream (and preferably - one of these which we have to support) then simply skip it
    if(!gst_element_link(_source, _tee)) {
        qCCritical(VideoReceiverLog) << "Unable to link source";
        return;
    }

    if (!_streaming) {
        _streaming = true;
        qCDebug(VideoReceiverLog) << "Streaming started" << _uri;
        _dispatchSignal([this](){
            emit streamingChanged(_streaming);
        });
    }

    gst_pad_add_probe(pad, GST_PAD_PROBE_TYPE_EVENT_DOWNSTREAM, _eosProbe, this, nullptr);

    if (_videoSink == nullptr) {
        return;
    }

    GST_DEBUG_BIN_TO_DOT_FILE(GST_BIN(_pipeline), GST_DEBUG_GRAPH_SHOW_ALL, "pipeline-with-new-source-pad");

    if (!_addDecoder(_decoderValve)) {
        qCCritical(VideoReceiverLog) << "_addDecoder() failed";
        return;
    }

    g_object_set(_decoderValve, "drop", FALSE, nullptr);

    qCDebug(VideoReceiverLog) << "Decoding started" << _uri;
}

void
GstVideoReceiver::_onNewDecoderPad(GstPad* pad)
{
    GST_DEBUG_BIN_TO_DOT_FILE(GST_BIN(_pipeline), GST_DEBUG_GRAPH_SHOW_ALL, "pipeline-with-new-decoder-pad");

    qCDebug(VideoReceiverLog) << "_onNewDecoderPad" << _uri;

    if (!_addVideoSink(pad)) {
        qCCritical(VideoReceiverLog) << "_addVideoSink() failed";
    }
}

bool
GstVideoReceiver::_addDecoder(GstElement* src)
{
    GstPad* srcpad;

    if ((srcpad = gst_element_get_static_pad(src, "src")) == nullptr) {
        qCCritical(VideoReceiverLog) << "gst_element_get_static_pad() failed";
        return false;
    }

    GstCaps* caps;

    if ((caps = gst_pad_query_caps(srcpad, nullptr)) == nullptr) {
        qCCritical(VideoReceiverLog) << "gst_pad_query_caps() failed";
        gst_object_unref(srcpad);
        srcpad = nullptr;
        return false;
    }

    gst_object_unref(srcpad);
    srcpad = nullptr;

    if ((_decoder = _makeDecoder()) == nullptr) {
        qCCritical(VideoReceiverLog) << "_makeDecoder() failed";
        gst_caps_unref(caps);
        caps = nullptr;
        return false;
    }

    gst_object_ref(_decoder);

    gst_caps_unref(caps);
    caps = nullptr;

    gst_bin_add(GST_BIN(_pipeline), _decoder);

    gst_element_sync_state_with_parent(_decoder);

    GST_DEBUG_BIN_TO_DOT_FILE(GST_BIN(_pipeline), GST_DEBUG_GRAPH_SHOW_ALL, "pipeline-with-decoder");

    if (!gst_element_link(src, _decoder)) {
        qCCritical(VideoReceiverLog) << "Unable to link decoder";
        return false;
    }

    GstPad* srcPad = nullptr;

    GstIterator* it;

    if ((it = gst_element_iterate_src_pads(_decoder)) != nullptr) {
        GValue vpad = G_VALUE_INIT;

        if (gst_iterator_next(it, &vpad) == GST_ITERATOR_OK) {
            srcPad = GST_PAD(g_value_get_object(&vpad));
            gst_object_ref(srcPad);
            g_value_reset(&vpad);
        }

        gst_iterator_free(it);
        it = nullptr;
    }

    if (srcPad != nullptr) {
        _onNewDecoderPad(srcPad);
        gst_object_unref(srcPad);
        srcPad = nullptr;
    } else {
        g_signal_connect(_decoder, "pad-added", G_CALLBACK(_onNewPad), this);
    }

    return true;
}

bool
GstVideoReceiver::_addVideoSink(GstPad* pad)
{
    GstCaps* caps = gst_pad_query_caps(pad, nullptr);

    if (caps != nullptr) {
        gchar* capsStr = gst_caps_to_string(caps);
        qInfo() << "[GstVideoReceiver]" << "_addVideoSink"
                << "uri" << _uri
                << "caps" << (capsStr ? capsStr : "<null>");
        if (capsStr != nullptr) {
            g_free(capsStr);
            capsStr = nullptr;
        }
    } else {
        qWarning() << "[GstVideoReceiver]" << "_addVideoSink"
                   << "uri" << _uri
                   << "caps query returned null";
    }

    gst_object_ref(_videoSink); // gst_bin_add() will steal one reference

    gst_bin_add(GST_BIN(_pipeline), _videoSink);

    if(!gst_element_link(_decoder, _videoSink)) {
        gst_bin_remove(GST_BIN(_pipeline), _videoSink);
        qCCritical(VideoReceiverLog) << "Unable to link video sink";
        if (caps != nullptr) {
            gst_caps_unref(caps);
            caps = nullptr;
        }
        return false;
    }

    gst_element_sync_state_with_parent(_videoSink);

    configureVideoSinkProfile(_videoSink, QStringLiteral("videoSink.configured"));
    _logElementProperty("videoSink", _videoSink, "sync");
    _logReceiverChecklistProperties("videoSink-configured", _videoSink);

    GST_DEBUG_BIN_TO_DOT_FILE(GST_BIN(_pipeline), GST_DEBUG_GRAPH_SHOW_ALL, "pipeline-with-videosink");

    if (_decoderValve != nullptr) {
        // Extracing video size from source is more guaranteed
        GstPad* valveSrcPad = gst_element_get_static_pad(_decoderValve, "src");
        GstCaps* valveSrcPadCaps = gst_pad_query_caps(valveSrcPad, nullptr);
        GstStructure* s = gst_caps_get_structure(valveSrcPadCaps, 0);

        if (s != nullptr) {
            gint width, height;
            gst_structure_get_int(s, "width", &width);
            gst_structure_get_int(s, "height", &height);
            _dispatchSignal([this, width, height](){
                emit videoSizeChanged(QSize(width, height));
            });
        }

        gst_caps_unref(caps);
        caps = nullptr;
    } else {
        _dispatchSignal([this](){
            emit videoSizeChanged(QSize(0, 0));
        });
    }

    return true;
}

void
GstVideoReceiver::_noteTeeFrame(void)
{
    _lastSourceFrameTime = QDateTime::currentSecsSinceEpoch();
}

void
GstVideoReceiver::_noteVideoSinkFrame(void)
{
    _lastVideoFrameTime = QDateTime::currentSecsSinceEpoch();
    if (!_decoding) {
        _decoding = true;
        qCDebug(VideoReceiverLog) << "Decoding started";
        _dispatchSignal([this](){
            emit decodingChanged(_decoding);
        });
    }
}

void
GstVideoReceiver::_noteEndOfStream(void)
{
    _endOfStream = true;
}

// -Unlink the branch from the src pad
// -Send an EOS event at the beginning of that branch
bool
GstVideoReceiver::_unlinkBranch(GstElement* from)
{
    GstPad* src;

    if ((src = gst_element_get_static_pad(from, "src")) == nullptr) {
        qCCritical(VideoReceiverLog) << "gst_element_get_static_pad() failed";
        return false;
    }

    GstPad* sink;

    if ((sink = gst_pad_get_peer(src)) == nullptr) {
        gst_object_unref(src);
        src = nullptr;
        qCCritical(VideoReceiverLog) << "gst_pad_get_peer() failed";
        return false;
    }

    if (!gst_pad_unlink(src, sink)) {
        gst_object_unref(src);
        src = nullptr;
        gst_object_unref(sink);
        sink = nullptr;
        qCCritical(VideoReceiverLog) << "gst_pad_unlink() failed";
        return false;
    }

    gst_object_unref(src);
    src = nullptr;

    // Send EOS at the beginning of the branch
    const gboolean ret = gst_pad_send_event(sink, gst_event_new_eos());

    gst_object_unref(sink);
    sink = nullptr;

    if (!ret) {
        qCCritical(VideoReceiverLog) << "Branch EOS was NOT sent";
        return false;
    }

    qCDebug(VideoReceiverLog) << "Branch EOS was sent";

    return true;
}

void
GstVideoReceiver::_shutdownDecodingBranch(void)
{
    if (_decoder != nullptr) {
        GstObject* parent;

        if ((parent = gst_element_get_parent(_decoder)) != nullptr) {
            gst_bin_remove(GST_BIN(_pipeline), _decoder);
            gst_element_set_state(_decoder, GST_STATE_NULL);
            gst_object_unref(parent);
            parent = nullptr;
        }

        gst_object_unref(_decoder);
        _decoder = nullptr;
    }

    if (_videoSinkProbeId != 0) {
        GstPad* sinkpad;
        if ((sinkpad = gst_element_get_static_pad(_videoSink, "sink")) != nullptr) {
            gst_pad_remove_probe(sinkpad, _videoSinkProbeId);
            gst_object_unref(sinkpad);
            sinkpad = nullptr;
        }
        _videoSinkProbeId = 0;
    }

    _lastVideoFrameTime = 0;

    GstObject* parent;

    if ((parent = gst_element_get_parent(_videoSink)) != nullptr) {
        gst_bin_remove(GST_BIN(_pipeline), _videoSink);
        gst_element_set_state(_videoSink, GST_STATE_NULL);
        gst_object_unref(parent);
        parent = nullptr;
    }

    gst_object_unref(_videoSink);
    _videoSink = nullptr;

    _removingDecoder = false;

    if (_decoding) {
        _decoding = false;
        qCDebug(VideoReceiverLog) << "Decoding stopped";
        _dispatchSignal([this](){
            emit decodingChanged(_decoding);
        });
    }

    GST_DEBUG_BIN_TO_DOT_FILE(GST_BIN(_pipeline), GST_DEBUG_GRAPH_SHOW_ALL, "pipeline-decoding-stopped");
}

void
GstVideoReceiver::_shutdownRecordingBranch(void)
{
    gst_bin_remove(GST_BIN(_pipeline), _fileSink);
    gst_element_set_state(_fileSink, GST_STATE_NULL);
    gst_object_unref(_fileSink);
    _fileSink = nullptr;

    _removingRecorder = false;

    if (_recording) {
        _recording = false;
        qCDebug(VideoReceiverLog) << "Recording stopped";
        _dispatchSignal([this](){
            emit recordingChanged(_recording);
        });
    }

    GST_DEBUG_BIN_TO_DOT_FILE(GST_BIN(_pipeline), GST_DEBUG_GRAPH_SHOW_ALL, "pipeline-recording-stopped");
}

bool
GstVideoReceiver::_needDispatch(void)
{
    return _slotHandler.needDispatch();
}

void
GstVideoReceiver::_dispatchSignal(std::function<void()> emitter)
{
    _signalDepth += 1;
    emitter();
    _signalDepth -= 1;
}

gboolean
GstVideoReceiver::_onBusMessage(GstBus* bus, GstMessage* msg, gpointer data)
{
    Q_UNUSED(bus)
    Q_ASSERT(msg != nullptr && data != nullptr);
    GstVideoReceiver* pThis = (GstVideoReceiver*)data;

    switch (GST_MESSAGE_TYPE(msg)) {
    case GST_MESSAGE_ERROR:
        do {
            gchar* debug;
            GError* error;

            gst_message_parse_error(msg, &error, &debug);

            if (debug != nullptr) {
                qCDebug(VideoReceiverLog) << "GStreamer debug: " << debug;
                g_free(debug);
                debug = nullptr;
            }

            if (error != nullptr) {
                qCCritical(VideoReceiverLog) << "GStreamer error:" << error->message;
                g_error_free(error);
                error = nullptr;
            }

            pThis->_slotHandler.dispatch([pThis](){
                qCDebug(VideoReceiverLog) << "Stopping because of error";
                pThis->stop();
            });
        } while(0);
        break;
    case GST_MESSAGE_WARNING:
        do {
            gchar* debug = nullptr;
            GError* error = nullptr;

            gst_message_parse_warning(msg, &error, &debug);

            if (debug != nullptr) {
                qWarning() << "[GstVideoReceiver]" << "GST_MESSAGE_WARNING debug" << pThis->_uri << debug;
                g_free(debug);
                debug = nullptr;
            }

            if (error != nullptr) {
                qWarning() << "[GstVideoReceiver]" << "GST_MESSAGE_WARNING" << pThis->_uri << error->message;
                g_error_free(error);
                error = nullptr;
            }
        } while (0);
        break;
    case GST_MESSAGE_EOS:
        pThis->_slotHandler.dispatch([pThis](){
            qCDebug(VideoReceiverLog) << "Received EOS";
            pThis->_handleEOS();
        });
        break;
    case GST_MESSAGE_ELEMENT:
        do {
            const GstStructure* s = gst_message_get_structure (msg);

            if (!gst_structure_has_name (s, "GstBinForwarded")) {
                break;
            }

            GstMessage* forward_msg = nullptr;

            gst_structure_get(s, "message", GST_TYPE_MESSAGE, &forward_msg, NULL);

            if (forward_msg == nullptr) {
                break;
            }

            if (GST_MESSAGE_TYPE(forward_msg) == GST_MESSAGE_EOS) {
                pThis->_slotHandler.dispatch([pThis](){
                    qCDebug(VideoReceiverLog) << "Received branch EOS";
                    pThis->_handleEOS();
                });
            }

            gst_message_unref(forward_msg);
            forward_msg = nullptr;
        } while(0);
        break;
    default:
        break;
    }

    return TRUE;
}

void
GstVideoReceiver::_onDeepElementAdded(GstBin* bin, GstBin* subBin, GstElement* element, gpointer data)
{
    Q_UNUSED(bin)
    GstVideoReceiver* self = static_cast<GstVideoReceiver*>(data);
    if (self == nullptr || element == nullptr) {
        return;
    }

    const QString factoryName = gstFactoryName(element);
    const QString elementName = gstObjectName(GST_OBJECT(element));
    const QString subBinName = gstObjectName(GST_OBJECT(subBin));

    qCInfo(GStreamLog).noquote() << "[GstVideoReceiver] runtime-element-added"
                                 << "uri=" << self->_uri
                                 << "subBin=" << subBinName
                                 << "name=" << elementName
                                 << "factory=" << factoryName;

    self->_logElementSummary("runtime-element-added", element);
    configureStartupParserHints(element);
    configureRtspUdpRobustness(element, QStringLiteral("runtime-config"));
    configureQueueProfile(element, QStringLiteral("runtime-config"));
    configureVideoSinkProfile(element, QStringLiteral("runtime-config"));
    self->_logReceiverChecklistProperties("runtime-checklist", element);

    if (factoryName == QStringLiteral("rtpjitterbuffer")) {
        self->_logElementProperty("rtpjitterbuffer.runtime", element, "latency");
        self->_logElementProperty("rtpjitterbuffer.runtime", element, "drop-on-latency");
        self->_logElementProperty("rtpjitterbuffer.runtime", element, "mode");
        self->_logPadCaps("rtpjitterbuffer.runtime.src", element, "src");
    } else if (factoryName == QStringLiteral("h264parse")) {
        self->_logElementProperty("h264parse.runtime", element, "config-interval");
        self->_logElementProperty("h264parse.runtime", element, "disable-passthrough");
    } else if (factoryName == QStringLiteral("udpsrc")) {
        qCInfo(GStreamLog).noquote() << "[GstVideoReceiver] rtsp-runtime-transport"
                                        << "uri=" << self->_uri
                                        << "transport=udp"
                                        << "element=" << elementName;
        self->_logElementProperty("udpsrc.runtime", element, "port");
        self->_logElementProperty("udpsrc.runtime", element, "caps");
    } else if (factoryName == QStringLiteral("tcpclientsrc")) {
        qCInfo(GStreamLog).noquote() << "[GstVideoReceiver] rtsp-runtime-transport"
                                        << "uri=" << self->_uri
                                        << "transport=tcp"
                                        << "element=" << elementName;
    }

    if (self->_decoder != nullptr) {
        GstObject* parent = gst_object_get_parent(GST_OBJECT(element));
        const bool isDecoderChild = parent != nullptr && GST_ELEMENT(parent) == self->_decoder;
        if (parent != nullptr) {
            gst_object_unref(parent);
        }

        if (isDecoderChild &&
            factoryName != QStringLiteral("decodebin3") &&
            factoryName != QStringLiteral("parsebin") &&
            !factoryName.endsWith(QStringLiteral("queue"))) {
            qCInfo(GStreamLog).noquote() << "[GstVideoReceiver] decoder-selected"
                                            << "uri=" << self->_uri
                                            << "factory=" << factoryName
                                            << "name=" << elementName;
        }
    }
}

void
GstVideoReceiver::_onChildAdded(GstChildProxy* childProxy, GObject* object, gchar* name, gpointer data)
{
    Q_UNUSED(childProxy)
    GstVideoReceiver* self = static_cast<GstVideoReceiver*>(data);
    if (self == nullptr || object == nullptr || !GST_IS_ELEMENT(object)) {
        return;
    }

    GstElement* element = GST_ELEMENT(object);
    const QString childName = name != nullptr ? QString::fromUtf8(name) : gstObjectName(GST_OBJECT(element));

    qCInfo(GStreamLog).noquote() << "[GstVideoReceiver] child-added"
                                 << "uri=" << self->_uri
                                 << "child=" << childName
                                 << "factory=" << gstFactoryName(element);

    configureStartupParserHints(element);
    configureRtspUdpRobustness(element, QStringLiteral("child-config"));
    configureQueueProfile(element, QStringLiteral("child-config"));
    configureVideoSinkProfile(element, QStringLiteral("child-config"));
    self->_logElementSummary("child-added", element);
    self->_logReceiverChecklistProperties("child-checklist", element);
    if (gstFactoryName(element) == QStringLiteral("h264parse")) {
        self->_logElementProperty("h264parse.child", element, "config-interval");
        self->_logElementProperty("h264parse.child", element, "disable-passthrough");
    }
}

void
GstVideoReceiver::_onRtspNewManager(GstElement* src, GstElement* manager, gpointer data)
{
    GstVideoReceiver* self = static_cast<GstVideoReceiver*>(data);
    if (self == nullptr || manager == nullptr) {
        return;
    }

    qCInfo(GStreamLog).noquote() << "[GstVideoReceiver] rtspsrc-new-manager"
                                    << "uri=" << self->_uri
                                    << "source=" << gstObjectName(GST_OBJECT(src))
                                    << "manager=" << gstObjectName(GST_OBJECT(manager))
                                    << "factory=" << gstFactoryName(manager);

    self->_logElementSummary("rtspsrc.manager", manager);
    self->_logElementProperty("rtspsrc.source", src, "latency");
    self->_logElementProperty("rtspsrc.source", src, "drop-on-latency");
    self->_logElementProperty("rtspsrc.source", src, "protocols");
    self->_logReceiverChecklistProperties("rtspsrc-source-checklist", src);

    if (GST_IS_BIN(manager)) {
        g_signal_connect(manager, "deep-element-added", G_CALLBACK(_onDeepElementAdded), self);
    }
    if (GST_IS_CHILD_PROXY(manager)) {
        g_signal_connect(manager, "child-added", G_CALLBACK(_onChildAdded), self);
    }
}

void
GstVideoReceiver::_onNewPad(GstElement* element, GstPad* pad, gpointer data)
{
    GstVideoReceiver* self = static_cast<GstVideoReceiver*>(data);

    if (element == self->_source) {
        self->_onNewSourcePad(pad);
    } else if (element == self->_decoder) {
        self->_onNewDecoderPad(pad);
    } else {
        qCDebug(VideoReceiverLog) << "Unexpected call!";
    }
}

void
GstVideoReceiver::_wrapWithGhostPad(GstElement* element, GstPad* pad, gpointer data)
{
    Q_UNUSED(data)

    gchar* name;

    if ((name = gst_pad_get_name(pad)) == nullptr) {
        qCCritical(VideoReceiverLog) << "gst_pad_get_name() failed";
        return;
    }

    GstPad* ghostpad;

    if ((ghostpad = gst_ghost_pad_new(name, pad)) == nullptr) {
        qCCritical(VideoReceiverLog) << "gst_ghost_pad_new() failed";
        g_free(name);
        name = nullptr;
        return;
    }

    g_free(name);
    name = nullptr;

    gst_pad_set_active(ghostpad, TRUE);

    if (!gst_element_add_pad(GST_ELEMENT_PARENT(element), ghostpad)) {
        qCCritical(VideoReceiverLog) << "gst_element_add_pad() failed";
    }
}

void
GstVideoReceiver::_linkPad(GstElement* element, GstPad* pad, gpointer data)
{
    gchar* name;

    if ((name = gst_pad_get_name(pad)) != nullptr) {
        if(gst_element_link_pads(element, name, GST_ELEMENT(data), "sink") == false) {
            qCCritical(VideoReceiverLog) << "gst_element_link_pads() failed";
        }

        g_free(name);
        name = nullptr;
    } else {
        qCCritical(VideoReceiverLog) << "gst_pad_get_name() failed";
    }
}

gboolean
GstVideoReceiver::_padProbe(GstElement* element, GstPad* pad, gpointer user_data)
{
    Q_UNUSED(element)

    int* probeRes = (int*)user_data;

    *probeRes |= 1;

    GstCaps* filter = gst_caps_from_string("application/x-rtp");

    if (filter != nullptr) {
        GstCaps* caps = gst_pad_query_caps(pad, nullptr);

        if (caps != nullptr) {
            if (!gst_caps_is_any(caps) && gst_caps_can_intersect(caps, filter)) {
                *probeRes |= 2;
            }

            gst_caps_unref(caps);
            caps = nullptr;
        }

        gst_caps_unref(filter);
        filter = nullptr;
    }

    return TRUE;
}

GstPadProbeReturn
GstVideoReceiver::_teeProbe(GstPad* pad, GstPadProbeInfo* info, gpointer user_data)
{
    Q_UNUSED(pad)
    Q_UNUSED(info)

    if(user_data != nullptr) {
        GstVideoReceiver* pThis = static_cast<GstVideoReceiver*>(user_data);
        pThis->_noteTeeFrame();
    }

    return GST_PAD_PROBE_OK;
}

GstPadProbeReturn
GstVideoReceiver::_videoSinkProbe(GstPad* pad, GstPadProbeInfo* info, gpointer user_data)
{
    Q_UNUSED(pad)
    Q_UNUSED(info)

    if(user_data != nullptr) {
        GstVideoReceiver* pThis = static_cast<GstVideoReceiver*>(user_data);

        if (pThis->_resetVideoSink) {
            pThis->_resetVideoSink = false;

// FIXME: AV: this makes MPEG2-TS playing smooth but breaks RTSP
//            gst_pad_send_event(pad, gst_event_new_flush_start());
//            gst_pad_send_event(pad, gst_event_new_flush_stop(TRUE));

//            GstBuffer* buf;

//            if ((buf = gst_pad_probe_info_get_buffer(info)) != nullptr) {
//                GstSegment* seg;

//                if ((seg = gst_segment_new()) != nullptr) {
//                    gst_segment_init(seg, GST_FORMAT_TIME);

//                    seg->start = buf->pts;

//                    gst_pad_send_event(pad, gst_event_new_segment(seg));

//                    gst_segment_free(seg);
//                    seg = nullptr;
//                }

//                gst_pad_set_offset(pad, -static_cast<gint64>(buf->pts));
//            }
        }

        pThis->_noteVideoSinkFrame();
    }

    return GST_PAD_PROBE_OK;
}

GstPadProbeReturn
GstVideoReceiver::_eosProbe(GstPad* pad, GstPadProbeInfo* info, gpointer user_data)
{
    Q_UNUSED(pad);
    Q_ASSERT(user_data != nullptr);

    if(info != nullptr) {
        GstEvent* event = gst_pad_probe_info_get_event(info);

        if (GST_EVENT_TYPE(event) == GST_EVENT_EOS) {
            GstVideoReceiver* pThis = static_cast<GstVideoReceiver*>(user_data);
            pThis->_noteEndOfStream();
        }
    }

    return GST_PAD_PROBE_OK;
}

GstPadProbeReturn
GstVideoReceiver::_keyframeWatch(GstPad* pad, GstPadProbeInfo* info, gpointer user_data)
{
    if (info == nullptr || user_data == nullptr) {
        qCCritical(VideoReceiverLog) << "Invalid arguments";
        return GST_PAD_PROBE_DROP;
    }

    GstBuffer* buf = gst_pad_probe_info_get_buffer(info);

    if (GST_BUFFER_FLAG_IS_SET(buf, GST_BUFFER_FLAG_DELTA_UNIT)) { // wait for a keyframe
        return GST_PAD_PROBE_DROP;
    }

    // set media file '0' offset to current timeline position - we don't want to touch other elements in the graph, except these which are downstream!
    gst_pad_set_offset(pad, -static_cast<gint64>(buf->pts));

    GstVideoReceiver* pThis = static_cast<GstVideoReceiver*>(user_data);

    qCDebug(VideoReceiverLog) << "Got keyframe, stop dropping buffers";

    pThis->_dispatchSignal([pThis]() {
        pThis->recordingStarted();
    });

    return GST_PAD_PROBE_REMOVE;
}
