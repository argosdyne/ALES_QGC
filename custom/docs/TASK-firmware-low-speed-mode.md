# TASK — 펌웨어 저속 모드(Low-speed mode) 전역 적용 (APM4.5, EASA C2)

작성 2026-11-21 · 대상: 회사 펌웨어 `~/APM4.5` (ArduCopter 4.5 기반, `AQUILA_FIRMWARE_VERSION "Z01.07.00EASA"`)
관련: alesQGC Simple UI Figma `AQGC-simpler` S28 / S79 / S104 / S105 (저속 모드 화면), 앱 결정 2026-11-21 "A안"

## 1. 왜 바꾸나

### 1.1 규정 요구 사항

| 근거 | 내용 |
|---|---|
| 위임규정 (EU) 2019/945, Part 3 (C2 클래스) | 고정익이 아니면 **조종자가 선택할 수 있는 저속 모드**를 갖추고, 저속 모드는 **지면 속도(ground speed)를 3 m/s 이하로 제한**해야 한다. |
| 시행규정 (EU) 2019/947, UAS.OPEN.030 (A2 하위 범주) | C2는 관련 없는 사람과 수평 30 m를 지킨다. **저속 모드가 켜져 있으면 5 m까지** 줄일 수 있다(조종자가 날씨·기체 성능·구역 분리를 평가한 뒤). |
| 해석 자료 (EASA FAQ 116464, 회원국 안내) | 저속 모드가 켜져 있으면 "어떤 때에도" 3 m/s를 넘지 않아야 한다 — 5 m 접근이 허용되는 근거이기 때문. |
| EN 4709-001 (C 클래스 시험 표준) | 저속 모드 시험 방법이 들어 있음. **원문으로 시험 절차·허용 오차를 확인할 것** (공개 자료에서는 확인 못 함). |

출처: EUR-Lex 2019/945 (https://eur-lex.europa.eu/eli/reg_del/2019/945),
2019/947 Annex Part A (https://legislation.gov.uk/eur/2019/947/annex/part/A/division/3),
EASA FAQ (https://www.easa.europa.eu/en/node/116464).

### 1.2 지금 펌웨어의 한계

- 저속은 **비행 모드 30 `SLOWMODE`** 하나로만 구현되어 있다(`ArduCopter/mode_slow.cpp`, `libraries/AC_WPNav/AC_Slow.*`).
  Loiter와 같고, 수평 속도를 `SLOW_SPEED`(20–300 cm/s, 기본·상한 300)로 묶는다. 지면 속도 기준이다(EKF 속도, `AC_Slow.cpp` 215–270행).
- 조종자가 Slow를 켠 상태에서 **귀환(RTL) · 임무(Auto) · 여기로 이동(Guided) · Smart RTL** 등을 고르면 모드가 바뀌면서 3 m/s 제한이 풀린다.
  그때 기체는 `RTL_SPEED` / `WPNAV_SPEED` / 임무의 DO_CHANGE_SPEED 속도(예: 영역 매핑 10 m/s)로 난다.
  → 조종자는 "저속 모드 켜짐"으로 알고 5 m까지 접근했는데 실제로는 빠르게 날 수 있다. C2 저속 모드 요구와 맞지 않는다.

## 2. 목표 (A안: 펌웨어가 전역으로 제한)

1. **저속 모드는 비행 모드가 아니라 기체 상태(on/off)** 다. 켜져 있는 동안은 **어떤 비행 모드에서도 수평 지면 속도 ≤ `SLOW_SPEED` (≤ 3 m/s)**.
2. 조종자가 앱(MAVLink)으로 켜고 끈다. (선택: 조종기 스위치로도.)
3. 상태는 GCS가 읽을 수 있어야 하고, 바뀔 때 GCS에 알린다.
4. 수평 속도를 직접 제어하지 않는 모드(스틱 각도 모드)에서는 3 m/s를 보장할 수 없으므로, 저속 모드가 켜져 있으면 **그 모드로 들어가지 않는다**(페일세이프는 예외, 아래 3.4).
5. 수직 속도(이륙·상승·하강·착륙)는 바꾸지 않는다. 규정은 지면(수평) 속도만 말한다.

## 3. 설계 제안

### 3.1 인터페이스 (앱과의 약속)

| 항목 | 제안 | 비고 |
|---|---|---|
| 상태 파라미터 | **`SLOW_ON`** (INT8, 0 = 끔, 1 = 켬). `AC_Slow` 그룹의 새 항목(예: index 7). | 파라미터라서 GCS가 목록에서 읽고 `PARAM_SET`으로 바꿀 수 있고, 바뀌면 `PARAM_VALUE`가 나간다. 재부팅 후에도 유지. |
| 기본값 | EASA 빌드에서 **1** (켬) | 앱도 이륙 시트에서 기본 켬(Figma S105). 펌웨어 기본값도 켬이면 앱 없이 날려도 안전한 쪽. |
| 제한 속도 | 기존 **`SLOW_SPEED`** (20–300 cm/s, 300 상한 유지) | 새 파라미터를 만들지 않는다. |
| 비행 중 변경 | 허용 (켜기·끄기 모두) | 끄면 바로 원래 모드 속도로. 켜면 현재 속도에서 `SLOW_BRK_*`처럼 부드럽게 감속. |
| 알림 | 바뀔 때 `STATUSTEXT` (MAV_SEVERITY_INFO): `Low speed ON (3.0 m/s)` / `Low speed OFF` | 앱은 메시지 목록과 상단 표시에 사용. 문구를 바꾸면 앱 쪽에 알려 줄 것. |
| 거부 알림 | 저속 모드 때문에 모드 변경을 거부하면 `STATUSTEXT` (MAV_SEVERITY_WARNING): `Low speed: <MODE> not allowed` | 앱은 S79 고급 모드 시트에서 그 모드를 회색으로 표시할 예정. |
| 조종기 스위치 (선택) | 새 RC 보조 기능 `LOW_SPEED_MODE` — 번호는 회사 전용으로 정할 것(예: 240, 업스트림과 겹치지 않게 확인). 스위치 HIGH = `SLOW_ON` 1, LOW = 0 | 스위치를 쓰면 앱 표시와 어긋나지 않도록 스위치도 `SLOW_ON` 파라미터를 바꾸는 방식으로. |

기존 모드 30 `SLOWMODE`는 호환을 위해 남긴다: **Slow 모드로 들어가면 `SLOW_ON`=1로 만들고 Loiter처럼 동작**(현재 동작과 같음). 앱의 새 화면은 모드 30을 쓰지 않고 `SLOW_ON`만 쓴다.

### 3.2 모드별 동작 (SLOW_ON = 1일 때)

| 모드 | 동작 | 구현 위치(제안) |
|---|---|---|
| Loiter, Slow(30) | 수평 속도 ≤ SLOW_SPEED | `AC_Loiter` 속도 상한 = min(`LOIT_SPEED`, SLOW_SPEED). Slow는 현재 그대로. |
| Auto (임무) | 모든 구간 ≤ SLOW_SPEED. 임무의 `DO_CHANGE_SPEED`도 상한 적용 | `AC_WPNav::set_speed_xy`, `wp_and_spline_init`, `ModeAuto::do_change_speed` |
| Guided (여기로 이동, 이륙 뒤 대기) | 위치 목표: 이동 속도 ≤ SLOW_SPEED. 속도 명령(`SET_POSITION_TARGET` velocity)도 크기 제한 | `ModeGuided` 위치/속도 입력부, `AC_WPNav` |
| RTL, Auto RTL | 귀환 수평 속도 ≤ SLOW_SPEED (`RTL_SPEED`/`WPNAV_SPEED` 대신) | `ModeRTL` 속도 설정부 |
| Smart RTL | ≤ SLOW_SPEED | `ModeSmartRTL` (`wp_nav` 속도) |
| Land | 착륙 중 위치 보정·조종자 수평 조작 ≤ SLOW_SPEED | `ModeLand` / `land_run_horizontal_control` |
| Brake | 감속만 하므로 변경 없음 | — |
| Circle | 선속도(반지름 × 각속도) ≤ SLOW_SPEED | `AC_Circle` 각속도 상한 |
| Follow | 추종 속도 ≤ SLOW_SPEED | `ModeFollow` |
| ZigZag | ≤ SLOW_SPEED | `ModeZigZag` (`wp_nav`) |
| PosHold | 조종자 각도 모드 구간이 있어 지면 속도를 보장하기 어려움 → **진입 거부** (또는 Loiter로 대체) | `Copter::set_mode` |
| Stabilize, Alt Hold, Acro, Sport, Drift, FlowHold, Guided_NoGPS | 수평 속도 제어 없음 → **진입 거부** | `Copter::set_mode` |
| Throw, Turtle, SystemID, Autotune 등 | 정비·특수 모드 → **진입 거부** | `Copter::set_mode` |

권장 구현: 모드마다 고치는 대신 **`AC_PosControl`에서 한 번에 상한**을 거는 방법을 먼저 검토할 것.

- `AC_PosControl::set_max_speed_accel_xy()` / `set_correction_speed_accel_xy()`에 들어오는 속도를 `copter.low_speed_limit_cms()`로 자른다.
- `input_vel_accel_xy()` / `input_pos_vel_accel_xy()`의 목표 속도 벡터 크기도 같은 값으로 자른다.
- 그러면 위치 제어를 쓰는 모든 모드에 자동으로 적용된다.
- 다만 라이브러리(`AC_PosControl`)가 Copter에 의존하지 않게 하려면, 예를 들어 `AC_PosControl::set_horizontal_speed_cap(float cms)`를 추가하고 Copter가 매 루프 값을 넣는 방식이 좋다. 0이면 상한 없음.
- 그래도 각 모드의 "요청 속도"(WPNAV_SPEED 등)가 상한보다 크면 경로 계획(S-curve)이 큰 속도로 계획되므로, `AC_WPNav`의 경로 계획 속도에도 같은 상한을 적용해야 실제 속도와 예상 시간이 맞는다.

### 3.3 켜고 끌 때

- **켤 때(비행 중, 3 m/s보다 빠를 때):** 갑자기 멈추지 말고 `SLOW_BRK_ACCEL` / `SLOW_BRK_JERK` 범위에서 감속. 감속하는 동안의 속도 초과는 시험 허용 범위로 정리(EN 4709-001 확인).
- **끌 때:** 다음 루프부터 모드 원래 속도. 임무·귀환 중이면 그 구간 속도로 돌아간다.
- 상태가 바뀌면 3.1의 `STATUSTEXT` 보냄. `PARAM_VALUE`도 나감(파라미터이므로).

### 3.4 모드 변경 거부와 페일세이프

- `Copter::set_mode()`에서 `SLOW_ON`=1이고 새 모드가 3.2의 "진입 거부" 모드면 false + 경고 `STATUSTEXT`.
- **예외: `ModeReason`이 페일세이프**(배터리, EKF, GCS, 라디오, 지오펜스, 테더 등)인 경우에는 막지 않는다. 안전 동작이 우선.
  단, EKF 페일세이프로 Alt Hold/Land에 들어가면 위치 제어가 없으므로 지면 속도 제한을 보장할 수 없음 — 이때 `STATUSTEXT` 경고 `Low speed not guaranteed (no position)`.
- 저속 모드를 켜려는 순간 현재 모드가 "진입 거부" 모드(예: Stabilize)라면: 켜기를 거부하고 경고, 또는 켜고 Loiter로 바꾸기 — **둘 중 하나를 정하고 앱에 알릴 것.** 제안: 거부(조종자가 모드를 먼저 바꾼다).

### 3.5 바람과 GPS

- 제한은 **지면 속도**(EKF 수평 속도) 기준. 맞바람·뒷바람에서도 지면 속도 3 m/s 이하. 현재 `AC_Slow`와 같은 방식.
- GPS 위치가 나빠져 위치 제어를 못 하면(EKF 위치 상실) 보장 불가 → 3.4의 경고.

## 4. 앱(alesQGC) 쪽 계획 — 펌웨어 완료 후 맞출 것

- 이륙 시트(S105): "이륙 뒤 저속 모드 · 최대 3 m/s" 스위치, **기본 켬**. 이륙 명령 전에 `SLOW_ON`을 스위치 값으로 씀.
- 비행 모드 시트(S28/S104): Slow는 모드 행이 아니라 **별도 스위치 "저속 모드 (≤ 3 m/s, 모든 비행에 적용)"** 로 바뀐다(Figma 수정 예정).
- 상단바: `SLOW_ON`=1이면 비행 모드 옆에 "저속 ≤ 3 m/s" 배지.
- 고급 모드 전체 모드 시트(S79): 저속 모드에서 거부되는 모드는 회색 + "저속 모드에서는 사용할 수 없음".
- `SLOW_ON` 파라미터가 없는 펌웨어(구버전)에서는 저속 스위치를 숨기고, 모드 30(Slow)이 있으면 지금처럼 모드로만 제공.

## 5. 시험 (SITL → 실기)

SITL: `sim_vehicle.py`/회사 `sitl.sh`, 풍속은 `SIM_WIND_SPD`, `SIM_WIND_DIR`. 로그의 `XKF1.VN/VE`(또는 `GPS.Spd`)로 수평 지면 속도를 본다. 판정: 정상 상태에서 ≤ 3.0 m/s (감속 구간 허용치는 EN 4709-001 기준으로 정함).

| # | 조건 | 기대 |
|---|---|---|
| 1 | `SLOW_ON`=1, Loiter, 스틱 최대 (무풍 / 맞바람 8 m/s / 뒷바람 8 m/s) | 지면 속도 ≤ 3 m/s |
| 2 | `SLOW_ON`=1, Auto 임무 (`WPNAV_SPEED` 1000, 임무에 DO_CHANGE_SPEED 10) | 모든 구간 ≤ 3 m/s |
| 3 | `SLOW_ON`=1, RTL (`RTL_SPEED` 1000), Smart RTL | ≤ 3 m/s |
| 4 | `SLOW_ON`=1, Guided 위치 목표 500 m 앞 / 속도 명령 10 m/s | ≤ 3 m/s |
| 5 | `SLOW_ON`=1, Circle 반지름 50 m, 각속도 큰 값 | 선속도 ≤ 3 m/s |
| 6 | `SLOW_ON`=1, Follow / ZigZag / Land 중 위치 보정 | ≤ 3 m/s |
| 7 | 10 m/s 비행 중 `SLOW_ON` 0→1 | 부드럽게 감속, 이후 ≤ 3 m/s, STATUSTEXT |
| 8 | `SLOW_ON` 1→0 (임무 중) | 구간 원래 속도로 복귀, STATUSTEXT |
| 9 | `SLOW_ON`=1에서 Stabilize / AltHold / Acro / Sport / Drift / PosHold 요청 (GCS, 조종기) | 거부 + 경고 STATUSTEXT, 모드 그대로 |
| 10 | `SLOW_ON`=1, 배터리·GCS·라디오 페일세이프 | 페일세이프 동작은 그대로 실행. RTL/Land는 ≤ 3 m/s |
| 11 | `SLOW_ON`=1, EKF 페일세이프(GPS 끊김) | 페일세이프 실행 + "not guaranteed" 경고 |
| 12 | 재부팅 | `SLOW_ON` 값 유지 |
| 13 | `SLOW_SPEED` 1000 입력 | 300으로 제한(기존과 같음) |
| 14 | 모드 30(Slow) 선택 | `SLOW_ON`=1이 되고 Loiter처럼, 지금과 같은 비행감 |
| 15 | (스위치 구현 시) RC 스위치 ON/OFF | `SLOW_ON` 따라 바뀜, PARAM_VALUE 나감 |

실기: 같은 항목 중 1, 2, 3, 7, 9, 10을 바람 있는 날 다시. 결과는 C2 기술 문서(저속 모드 시험 기록)에 첨부.

## 6. 정해야 할 것 (펌웨어팀 + 제품)

1. 파라미터 이름 `SLOW_ON` 확정 (다른 이름이면 앱에 알려 줄 것).
2. 펌웨어 기본값 1(켬)로 할지.
3. 진입 거부 모드 목록 확정 (특히 PosHold: 거부 vs. Loiter 대체).
4. 저속 켜기 요청 시 현재 모드가 거부 대상일 때의 동작(거부 vs. Loiter로 전환).
5. 조종기 스위치 보조 기능 번호(회사 전용 번호, 업스트림과 충돌 없게).
6. EN 4709-001의 저속 모드 시험 절차·허용 오차(감속 구간, 측정 방법) 확인.
7. 버전: 이 변경이 들어가는 펌웨어 버전 번호 (예: Z01.08.00EASA) — 앱은 `SLOW_ON` 존재 여부로 판단하므로 버전 비교는 필요 없음.
