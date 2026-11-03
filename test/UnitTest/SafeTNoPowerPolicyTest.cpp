#include "../../custom/src/Elistair/SafeTNoPowerPolicy.h"
#include <cassert>
#include <iostream>
int main() {
    using namespace SafeTNoPowerPolicy;
    assert(decodeIntegrity('0') == 0);
    assert(decodeIntegrity('1') == 1);
    assert(decodeIntegrity('2') == 2);
    assert(decodeIntegrity(2) == -1);
    assert(decodeIntegrity('5') == -1);
    assert(canDispatch(true, 2, true, false, true, true, true, true, true));
    assert(!canDispatch(false, 2, true, false, true, true, true, true, true));
    assert(!canDispatch(true, 0, true, false, true, true, true, true, true));
    assert(!canDispatch(true, 1, true, false, true, true, true, true, true));
    assert(!canDispatch(true, -1, true, false, true, true, true, true, true));
    assert(!canDispatch(true, 2, false, false, true, true, true, true, true));
    assert(!canDispatch(true, 2, true, true, true, true, true, true, true));
    assert(!canDispatch(true, 2, true, false, false, true, true, true, true));
    assert(!canDispatch(true, 2, true, false, true, false, true, true, true));
    assert(!canDispatch(true, 2, true, false, true, true, false, true, true));
    assert(!canDispatch(true, 2, true, false, true, true, true, false, true));
    assert(!canDispatch(true, 2, true, false, true, true, true, true, false));
    std::cout << "PASS: ASCII integrity, incident token, one-shot, station/vehicle freshness, target and Armed gates\n";
}
