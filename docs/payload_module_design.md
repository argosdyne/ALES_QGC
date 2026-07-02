# Thiết kế module Payload cho QGC (NextVision DragonEye2, Gremsy Lynx, R3, Sony ILX)

- **Branch:** `ALES_QGC_V01.22.00_UsbJoystick`
- **Ngày:** 2026-07-02
- **Mục tiêu:** Chuẩn hoá cách thêm/điều khiển các payload (camera/gimbal) sao cho **mỗi payload độc lập tối đa với code lõi**; thêm payload mới chỉ là *thêm một thư mục mới + vài dòng đăng ký*, không sửa rải rác trong `Vehicle`/`FlyView`.

---

## 1. Bối cảnh & vấn đề hiện tại

App đang hỗ trợ / đang làm dở 4 payload, nhưng theo **2 cơ chế khác hẳn nhau**:

| Payload | Cơ chế giao tiếp | Hiện trạng code |
|---|---|---|
| **Codev R3** (EO) | MAVLink camera protocol + camera definition XML | Trên đường camera chuẩn (`QGCCameraControl`/`QGCCameraManager`) |
| **Sony ILX / LR1** (CR) | MAVLink camera protocol + camera definition XML | Cùng đường camera chuẩn, khác XML + vài nhánh model-string |
| **NextVision DragonEye2** | Off-protocol: RC override qua UDP tới IP riêng + camera command | Có controller riêng `NextVisionController` |
| **Gremsy Lynx** | Off-protocol: gimbal MAVLink nằm **sau ArduPilot** | Code nhét thẳng vào `Vehicle` |

### 1.1. Các điểm coupling đang gây khó

1. **Gremsy Lynx bị nhét vào lõi `Vehicle`:**
   - `Vehicle::sendGremsyGimbalRate()` / `Vehicle::stopGremsyGimbal()` — khai báo `Vehicle.h:525-526`, cài đặt `Vehicle.cc:5423` và `Vehicle.cc:5488`.
   - Log `[GremsyLynx]` rải rác trong handler MAVLink của `Vehicle.cc` (nhiều chỗ quanh dòng 721–760, 5396…).
   - `Vehicle` (~5400 dòng) đang gánh logic đặc thù của một payload.

2. **UI Gremsy nằm sai module:** `GremsyLynxControl.qml` đặt trong `src/NextVision/` và gọi thẳng `vehicle.sendGremsyGimbalRate()` — không có controller riêng.

3. **NextVision tuy có controller riêng nhưng vẫn cứng nhắc:**
   - Khởi tạo per-vehicle tại `Vehicle.cc:592`, expose qua property `vehicle.nextVisionController` (`Vehicle.h:273, 966, 1319`).
   - IP/port/RC channel **hard-code** trong `NextVisionController` (`_dragonEyeIp`, `_dragonEyeRcPort = 10038`, `_pitchChannel = 9`…).

4. **`FlyView.qml` phải "đánh hơi" từng vendor:** `FlyView.qml:69-76` dùng chuỗi model/RTSP để suy ra `_isNextVisionCamera` / `_isGremsyCamera` rồi tự chọn panel & source (`FlyView.qml:188-219`). Lõi UI buộc phải biết chi tiết từng payload.

5. **Camera R3/Sony:** logic theo model phình trong file dùng chung — `_isR3CameraModel()` (`CodevCameraControl.cc:96`, dùng lại ở dòng 393, 1572) và `_isSonyIR1` (`CodevCameraVisual.qml:40`). Bản thân `CodevCameraControl.cc` đã ~79KB.

> **Hệ quả:** mỗi khi thêm payload theo kiểu off-protocol, phải sửa ở ≥3 nơi trong lõi (`Vehicle`, `FlyView`, thư mục dùng chung) → dễ vỡ, khó review, khó test độc lập.

---

## 2. Nguyên tắc thiết kế: phân biệt 2 LOẠI payload

Điểm mấu chốt: **không gộp mọi payload vào một khung.** Có 2 loại, mỗi loại có pattern module đúng riêng.

### Loại A — Camera theo MAVLink camera protocol (R3, Sony LR1)

- Payload phát `CAMERA_INFORMATION`, nhận camera command chuẩn, mô tả khả năng bằng **camera definition XML**.
- QGC **đã có sẵn** hạ tầng modular: `QGCCameraManager` (quản lý danh sách camera) + `QGCCameraControl` (parse XML, sinh UI settings) + subclass `CodevCameraControl`.
- Thêm camera loại này = **thêm data (XML)**, gần như không thêm logic.

### Loại B — Payload off-protocol (NextVision, Gremsy)

- Không đi theo camera protocol chuẩn: NextVision dùng UDP RC override tới IP riêng; Gremsy là gimbal MAVLink nằm sau ArduPilot.
- Cần **controller bespoke** → đây là chỗ áp dụng khung `PayloadManager` mô tả ở mục 3.

| Tiêu chí | Loại A (protocol camera) | Loại B (off-protocol) |
|---|---|---|
| Discovery | `CAMERA_INFORMATION` tự động | Tự dò/tự cấu hình trong controller |
| Mô tả khả năng | Camera definition XML | Code trong controller |
| UI settings | Tự sinh từ XML | QML panel riêng |
| Thêm mới | Thả 1 file XML | Viết 1 controller + 1 QML + đăng ký |
| Ví dụ | R3, Sony LR1 | NextVision, Gremsy |

> **Khuyến nghị R3 & Sony:** GIỮ trên đường camera-protocol, **không** biến thành controller bespoke (sẽ đi lùi, phải viết lại thứ `QGCCameraManager` đã làm). Nếu muốn gọn hơn: tách các nhánh theo-model (`_isR3CameraModel`, `_isSonyIR1`) thành strategy nhỏ / QML component riêng — nhưng đây là refactor **tùy chọn**, không bắt buộc.

---

## 3. Kiến trúc đích cho payload Loại B

### 3.1. Bố cục thư mục

```
src/Payload/
  PayloadController.h/.cc        # Abstract base (QObject) — API chung cho mọi payload
  PayloadManager.h/.cc           # Chọn payload active theo vehicle, expose ra QML
  CMakeLists.txt
  NextVision/
    NextVisionController.h/.cc   # : public PayloadController  (di chuyển từ src/NextVision)
    DragonEyeControl.qml
    NextVision.SettingsGroup.json
  GremsyLynx/
    GremsyLynxController.h/.cc    # : public PayloadController  (GỠ code khỏi Vehicle.cc)
    GremsyLynxControl.qml         # (di chuyển khỏi src/NextVision)
    GremsyLynx.SettingsGroup.json
```

> Có thể để phẳng theo convention hiện có (`src/NextVision`, `src/GremsyLynx`, `src/Microhard`), nhưng gom vào `src/Payload/` giúp thấy rõ đây là một nhóm và dễ đặt base class chung.

### 3.2. Base class `PayloadController`

Rút ra từ chính API `NextVisionController` đang có, thành các virtual method chung:

```cpp
class PayloadController : public QObject {
    Q_OBJECT
public:
    explicit PayloadController(Vehicle* vehicle, QObject* parent = nullptr);

    Q_PROPERTY(bool    connected   READ connected   NOTIFY connectedChanged)
    Q_PROPERTY(QString displayName READ displayName CONSTANT)
    Q_PROPERTY(QString controlQml  READ controlQml  CONSTANT)  // đường QML panel của payload
    Q_PROPERTY(QString rtspUrl     READ rtspUrl     NOTIFY rtspUrlChanged)

    // Điều khiển gimbal
    Q_INVOKABLE virtual void setRate(float pitchRate, float yawRate) {}
    Q_INVOKABLE virtual void setAngle(float pitchDeg, float yawDeg)  {}
    Q_INVOKABLE virtual void stopMotion()  {}
    Q_INVOKABLE virtual void center()      {}

    // Camera / sensor (payload nào không hỗ trợ thì để mặc định no-op)
    Q_INVOKABLE virtual void zoomIn()  {}
    Q_INVOKABLE virtual void zoomOut() {}
    Q_INVOKABLE virtual void stopZoom(){}
    Q_INVOKABLE virtual void selectEo(){}
    Q_INVOKABLE virtual void selectIr(){}
    Q_INVOKABLE virtual void takePhoto()      {}
    Q_INVOKABLE virtual void startRecording() {}
    Q_INVOKABLE virtual void stopRecording()  {}

    virtual bool    connected()   const = 0;
    virtual QString displayName() const = 0;
    virtual QString controlQml()  const = 0;
    virtual QString rtspUrl()     const { return {}; }

signals:
    void connectedChanged();
    void rtspUrlChanged();
    void commandFailed(QString command, QString reason);
};
```

- `NextVisionController` và `GremsyLynxController` kế thừa lớp này.
- **QML và joystick nói chuyện với interface**, không cần biết vendor cụ thể.

### 3.3. `PayloadManager` (per-vehicle)

Thay cho việc `FlyView` tự đoán vendor. Nó chứa logic chọn payload (theo vendor/model camera hoặc setting người dùng) và tạo controller tương ứng:

```cpp
class PayloadManager : public QObject {
    Q_OBJECT
public:
    Q_PROPERTY(PayloadController* active      READ active      NOTIFY activeChanged)
    Q_PROPERTY(bool               available   READ available   NOTIFY activeChanged)
    Q_PROPERTY(QString            displayName READ displayName NOTIFY activeChanged)
    Q_PROPERTY(QString            controlQml  READ controlQml  NOTIFY activeChanged)
    // ...
};
```

Logic chọn payload (vendor sniffing) chuyển **từ QML sang C++** — tập trung tại một chỗ, dễ test.

### 3.4. Điểm chạm lõi (chỉ còn 1)

- **`Vehicle`:** bỏ property `nextVisionController` + 2 hàm `sendGremsy*`; thay bằng đúng một:
  ```cpp
  Q_PROPERTY(PayloadManager* payloadManager READ payloadManager CONSTANT)
  ```
- **`FlyView.qml`:** bỏ toàn bộ khối sniff vendor (`FlyView.qml:69-76`), thay bằng:
  ```qml
  property var    _payload:            _activeVehicle ? _activeVehicle.payloadManager : null
  property bool   _showPayloadControl: _payload && _payload.available
  property string _payloadControlTitle:  _payload ? _payload.displayName : ""
  property string _payloadControlSource: _payload ? _payload.controlQml   : ""
  ```

### 3.5. Cấu hình per-payload (bỏ hard-code)

IP/port/RC channel đang hard-code trong `NextVisionController` → đưa vào file `*.SettingsGroup.json` riêng mỗi payload (theo mẫu `GimbalFact.json` / `Codev.SettingsGroup.json`), để đổi thiết bị không phải sửa code.

### 3.6. Joystick

Theo hiện trạng, trục analog đã nối tới `GimbalController::gimbalAxisControl`. Với payload off-protocol, cho `PayloadManager.active` làm đích để joystick handler kết nối **một lần** tới interface `PayloadController`, không phân nhánh theo vendor.

---

## 4. Kế hoạch di chuyển (migration)

Thứ tự đề xuất, mỗi bước build được độc lập:

1. **Tạo khung:** thêm `PayloadController` (base) + `PayloadManager`, khai báo build ở `qgroundcontrol.pro` và `src/CMakeLists.txt`.
2. **Bọc NextVision:** cho `NextVisionController` kế thừa `PayloadController`; `PayloadManager` tạo nó khi phát hiện camera NextVision. Chưa xoá đường cũ để so sánh.
3. **Tách Gremsy khỏi `Vehicle`:** tạo `GremsyLynxController` chứa `sendGremsyGimbalRate`/`stopGremsyGimbal` + log `[GremsyLynx]`; `GremsyLynxControl.qml` gọi controller thay vì `vehicle.*`.
4. **Chuyển `FlyView.qml`** sang dùng `payloadManager` (mục 3.4), gỡ sniff vendor.
5. **Bỏ đường cũ trên `Vehicle`:** xoá property `nextVisionController` và 2 hàm `sendGremsy*` sau khi đã xác nhận đường mới chạy.
6. **Đưa hard-code vào SettingsGroup JSON.**

---

## 5. Thêm payload MỚI cần gì?

### Kịch bản A — Camera nói đúng camera protocol (như R3, Sony)
Gần như **không cần code**:
- Thêm 1 camera definition XML vào `custom/res/CameraDefinitions/` + đăng ký `.qrc`.
- (Nếu tên file suy ra chưa khớp) chỉnh 1 dòng mapping tại `QGCCameraControl.cc:115`.

### Kịch bản B — Payload off-protocol (kênh riêng / gimbal đặc thù)
Khi đã có khung `PayloadManager`, lượng việc **cố định & khu trú**:

| # | Việc | File |
|---|---|---|
| 1 | Controller mới `: public PayloadController` | `src/Payload/Xxx/XxxController.h/.cc` (mới) |
| 2 | UI panel | `src/Payload/Xxx/XxxControl.qml` (mới) |
| 3 | Thêm 1 nhánh nhận diện | `PayloadManager` (~1 dòng) |
| 4 | Khai báo build | `qgroundcontrol.pro` **và** `src/CMakeLists.txt` |
| 5 | Đăng ký QML resource | `.qrc` (gốc + custom) |

**Không** đụng `Vehicle`, **không** đụng `FlyView` → đây là *code mới*, rủi ro thấp.

---

## 6. Lưu ý tích hợp bắt buộc

- **Project build song song qmake + CMake:** mọi file/module mới phải khai báo ở **cả** `qgroundcontrol.pro` (tham chiếu hiện tại: dòng 692 header, 967 source) **và** `src/CMakeLists.txt` (mỗi module có `CMakeLists.txt` riêng như `src/NextVision/CMakeLists.txt`). Thiếu một bên → lỗi build khó hiểu.
- **QML resource:** đăng ký ở cả `qgroundcontrol.qrc` (gốc) và `custom/qgroundcontrol.qrc`.
- **Gremsy Lynx còn vướng cấu hình phía FC:** Lynx nằm sau ArduPilot và mount manager của AP chưa cấu hình nên **không nhúc nhích được từ QGC** — đây là vấn đề riêng ở phía autopilot, tách module xong vẫn phải xử lý config này (không phải lỗi format message).

---

## 7. Câu hỏi cho người review

1. Đặt module ở `src/Payload/` (gom nhóm) hay để phẳng `src/NextVision`, `src/GremsyLynx` (theo convention hiện tại)?
2. `PayloadManager` chọn payload theo **vendor/model camera tự dò** hay theo **setting người dùng chọn tay**, hay cả hai (auto + override)?
3. Có refactor các nhánh model của R3/Sony trong `CodevCameraControl` ngay đợt này không, hay để sau (khuyến nghị: để sau)?
4. Mức độ chung của `PayloadController`: giữ đủ rộng (gimbal + camera + video) hay tách thành các interface nhỏ hơn (ví dụ `GimbalPayload` / `CameraPayload`)?
