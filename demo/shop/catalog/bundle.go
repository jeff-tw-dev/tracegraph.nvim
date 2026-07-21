// Package catalog models nested product bundles.
package catalog

import "shop/internal/logging"

// Node is a single product or a bundle of products.
type Node struct {
	SKU       string
	UnitCents int64
	Children  []*Node
}

// TotalCents sums this node and every nested bundle beneath it.
//
// It recurses, so tracing its callees is where tracegraph draws the ↻
// marker instead of descending forever.
func (n *Node) TotalCents() int64 {
	total := n.UnitCents
	for _, child := range n.Children {
		total += child.TotalCents()
	}

	logging.Debugf("catalog: %s totals %d", n.SKU, total)
	return total
}

// SampleBundle is a desk setup made of two nested bundles.
func SampleBundle() *Node {
	return &Node{
		SKU: "bundle-desk",
		Children: []*Node{
			{
				SKU: "bundle-typing",
				Children: []*Node{
					{SKU: "kbd-hhkb", UnitCents: 24900},
					{SKU: "mat-desk", UnitCents: 4500},
				},
			},
			{SKU: "mon-4k27", UnitCents: 59900},
		},
	}
}
