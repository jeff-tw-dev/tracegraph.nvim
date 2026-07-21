// Package pricing turns cart lines into a payable total.
package pricing

import "shop/internal/logging"

// Line is one priced row in a cart.
type Line struct {
	SKU       string
	Qty       int
	UnitCents int64
}

// Total sums the lines, applies the volume discount and rounds the result.
func Total(lines []Line) int64 {
	var subtotal int64
	for _, l := range lines {
		subtotal += int64(l.Qty) * l.UnitCents
	}

	total := roundCents(applyDiscount(subtotal, len(lines)))

	logging.Debugf("pricing: %d lines, subtotal=%d, total=%d", len(lines), subtotal, total)
	return total
}

// applyDiscount takes 5% off carts with three or more distinct lines.
func applyDiscount(subtotal int64, lines int) int64 {
	if lines < 3 {
		return subtotal
	}
	return subtotal - subtotal*5/100
}

// roundCents rounds to the nearest ten cents.
func roundCents(v int64) int64 {
	if r := v % 10; r < 5 {
		return v - r
	} else {
		return v + (10 - r)
	}
}
