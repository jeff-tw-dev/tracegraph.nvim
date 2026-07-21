// Command shop is a tiny order service used to demo tracegraph.nvim.
//
// The layers are deliberately thin so a trace from the shared logging
// helper walks back up through six frames:
//
//	logging.Debugf <- pricing.Total <- service.PlaceOrder <-
//	api.handleCheckout <- api.Run <- main
package main

import (
	"log"

	"shop/api"
	"shop/catalog"
	"shop/internal/logging"
	"shop/storage"
)

func main() {
	repo := storage.NewRepo("orders.db")
	srv := api.NewServer(repo)

	bundle := catalog.SampleBundle()
	logging.Infof("desk bundle totals %d cents", bundle.TotalCents())

	if err := srv.Run(":8080"); err != nil {
		log.Fatalf("shop: %v", err)
	}
}
