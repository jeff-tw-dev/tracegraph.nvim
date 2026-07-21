// Package api is the transport layer: it turns requests into service calls.
package api

import (
	"fmt"

	"shop/internal/logging"
	"shop/service"
	"shop/storage"
)

// Server accepts checkout requests and hands them to the order service.
type Server struct {
	orders *service.OrderService
}

func NewServer(repo *storage.Repo) *Server {
	return &Server{orders: service.New(repo)}
}

// Run drives the demo request loop.
func (s *Server) Run(addr string) error {
	logging.Infof("listening on %s", addr)

	for _, req := range sampleRequests() {
		if err := s.handleCheckout(req); err != nil {
			return fmt.Errorf("checkout for %s: %w", req.CustomerID, err)
		}
	}
	return nil
}

// handleCheckout is the handler for one checkout request.
func (s *Server) handleCheckout(req CheckoutRequest) error {
	order, err := s.orders.PlaceOrder(req.CustomerID, req.Items)
	if err != nil {
		return err
	}

	logging.Infof("order %s accepted, total %d cents", order.ID, order.TotalCents)
	return nil
}
