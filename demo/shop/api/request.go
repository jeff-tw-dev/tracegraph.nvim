package api

import "shop/service"

// CheckoutRequest is one decoded checkout payload.
type CheckoutRequest struct {
	CustomerID string
	Items      []service.Item
}

func sampleRequests() []CheckoutRequest {
	return []CheckoutRequest{
		{
			CustomerID: "cust-1001",
			Items: []service.Item{
				{SKU: "kbd-hhkb", Qty: 1, UnitCents: 24900},
				{SKU: "cable-usbc", Qty: 2, UnitCents: 1900},
				{SKU: "mat-desk", Qty: 1, UnitCents: 4500},
			},
		},
		{
			CustomerID: "cust-1002",
			Items: []service.Item{
				{SKU: "mon-4k27", Qty: 1, UnitCents: 59900},
			},
		},
	}
}
