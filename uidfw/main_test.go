package main

import "testing"

// Bit positions per Connectivity train; a wrong bit can be IIF_MATCH or a deny chain.
func TestAllowBitsFor(t *testing.T) {
	for train, want := range map[int]uint32{
		29: 0x14, // Q: doze + power save
		30: 0x14, // R: bit 5 is IIF_MATCH, must stay off
		31: 0x34, // S: + restricted; bit 6 is IIF_MATCH, must stay off
		32: 0x34,
		33: 0x74, // T: + low power standby
		34: 0x74,
		35: 0x1074, // V: + background
		37: 0x1074,
	} {
		if got := allowBitsFor(train); got != want {
			t.Errorf("train %d: got %#x want %#x", train, got, want)
		}
	}
}
