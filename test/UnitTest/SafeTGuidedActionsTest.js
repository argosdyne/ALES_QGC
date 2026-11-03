const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const source = fs.readFileSync(require('path').resolve(__dirname, '../../src/FlightDisplay/GuidedActionsController.qml'), 'utf8');
const context = {
    qsTr: s => s,
    Qt: { binding: fn => fn() },
    confirmDialog: { visible: false, action: 0, show() { this.visible = true; } },
    actionList: {}, guidedValueSlider: {}, setupSlider() {},
    _activeVehicle: { vehicleLinkManager: { communicationLost: false } },
    tetherBattery: { percentRemaining: { rawValue: 78 }, timeRemaining: { rawValue: 540 } },
    tetherStation: {
        powerOffPending: true, powerOffRequestId: 123, hasMonitoring: true, linkLost: false, powerRemote: true,
        offCommands: 0,
        cancelPowerOff() { this.powerOffPending = false; },
        confirmPowerOff(id) { if (this.powerOffPending && id === this.powerOffRequestId) { this.offCommands++; this.powerOffPending = false; } }
    }
};
for (const [, name, code] of source.matchAll(/readonly property int\s+(\w+):\s*(\d+)/g)) context[name] = Number(code);
context._root = context;
vm.createContext(context);
vm.runInContext('String.prototype.arg = function(v) { return this.replace(/%[12]/, v); }', context);
for (const name of ['tetherPowerOffMessage', 'cancelTetherPowerOff', 'closeAll', 'confirmAction', 'executeAction']) {
    const match = source.match(new RegExp('    function ' + name + '\\([^]*?\\n    }'));
    assert(match, name);
    vm.runInContext(match[0], context);
}
// Create strings inside the VM so its Qt .arg() shim applies.
context.qsTr = vm.runInContext('(s) => String(s)', context);
context.confirmAction(context.actionTetherPowerOff, 123);
assert(context.confirmDialog.visible);
assert(context.tetherStation.powerOffPending);
assert.equal(context.tetherStation.offCommands, 0, 'opening UI must not send OFF');
assert(context.confirmDialog.message.includes('78 %'));
assert(context.confirmDialog.message.includes('about 9 min'));
context.cancelTetherPowerOff();
context.executeAction(context.actionTetherPowerOff, 123);
assert.equal(context.tetherStation.offCommands, 0, 'cancelled action must not send OFF');
context.confirmDialog.visible = false;
context.tetherStation.powerOffPending = true;
context.tetherStation.powerOffRequestId = 124;
context.confirmAction(context.actionTetherPowerOff, 124);
context.executeAction(context.actionTetherPowerOff, 123);
assert.equal(context.tetherStation.offCommands, 0, 'stale request ID must not confirm');
context.executeAction(context.actionTetherPowerOff, 124);
context.executeAction(context.actionTetherPowerOff, 124);
assert.equal(context.tetherStation.offCommands, 1, 'confirmed action must be one-shot');
context.tetherBattery.timeRemaining.rawValue = NaN;
assert(context.tetherPowerOffMessage().includes('remaining time unavailable'));
console.log('PASS: production Guided action dispatch, no OFF before confirm, cancel, stale request, one-shot accept and battery message');
context.confirmDialog.visible = false;
Object.assign(context.tetherStation, {
    noPowerPrompt: true, noPowerIncident: 900, noReply: false,
    actions: [],
    executeNoPowerAction(id, rtl) {
        if (id === this.noPowerIncident && this.noPowerPrompt) {
            this.actions.push(rtl ? 'RTL' : 'Land'); this.noPowerPrompt = false;
        }
    }
});
context.confirmAction(context.actionTetherLand, 900);
assert(context.confirmDialog.visible);
assert.equal(context.tetherStation.actions.length, 0, 'Land sent before slide');
context.closeAll();
assert.equal(context.tetherStation.actions.length, 0, 'cancel sent Land');
context.confirmAction(context.actionTetherLand, 900);
context.executeAction(context.actionTetherLand, 899);
assert.equal(context.tetherStation.actions.length, 0, 'stale incident accepted');
context.executeAction(context.actionTetherLand, 900);
context.executeAction(context.actionTetherLand, 900);
assert.deepEqual(context.tetherStation.actions, ['Land']);
context.confirmDialog.visible = false;
context.tetherStation.noPowerPrompt = true;
context.tetherStation.noPowerIncident = 901;
context.confirmAction(context.actionTetherRTL, 901);
assert(context.confirmDialog.message.includes('Home'));
context.executeAction(context.actionTetherRTL, 901);
assert.deepEqual(context.tetherStation.actions, ['Land', 'RTL']);
console.log('PASS: ST-12 production Guided UI: no Land/RTL before confirm, cancel, stale token, one-shot and Home warning');
