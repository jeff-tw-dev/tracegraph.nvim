// Package service holds the order workflow.
package service

import (
	"errors"
	"fmt"

	"shop/internal/logging"
	"shop/notify"
	"shop/pricing"
)

// Item is one requested product line.
type Item struct {
	SKU       string
	Qty       int
	UnitCents int64
}

// Order is a placed order.
type Order struct {
	ID         string
	CustomerID string
	Items      []Item
	TotalCents int64
}

// Repository persists placed orders.
type Repository interface {
	NextID() string
	Save(o *Order) error
}

// OrderService turns a validated cart into a stored order.
type OrderService struct {
	repo Repository
}

func New(repo Repository) *OrderService {
	return &OrderService{repo: repo}
}

// PlaceOrder validates, prices, stores and announces one order.
func (s *OrderService) PlaceOrder(customerID string, items []Item) (*Order, error) {
	if err := validate(customerID, items); err != nil {
		return nil, err
	}

	order := &Order{
		ID:         s.repo.NextID(),
		CustomerID: customerID,
		Items:      items,
		TotalCents: pricing.Total(toLines(items)),
	}

	if err := s.repo.Save(order); err != nil {
		return nil, fmt.Errorf("save order: %w", err)
	}

	notify.OrderPlaced(order.CustomerID, order.ID, order.TotalCents)
	return order, nil
}

func toLines(items []Item) []pricing.Line {
	lines := make([]pricing.Line, 0, len(items))
	for _, it := range items {
		lines = append(lines, pricing.Line{SKU: it.SKU, Qty: it.Qty, UnitCents: it.UnitCents})
	}
	return lines
}

// validate rejects empty carts and non-positive quantities.
func validate(customerID string, items []Item) error {
	if customerID == "" {
		return errors.New("missing customer id")
	}
	if len(items) == 0 {
		return errors.New("empty cart")
	}
	for _, it := range items {
		if it.Qty <= 0 {
			return fmt.Errorf("item %s: quantity must be positive", it.SKU)
		}
	}

	logging.Debugf("service: cart for %s validated, %d items", customerID, len(items))
	return nil
}
