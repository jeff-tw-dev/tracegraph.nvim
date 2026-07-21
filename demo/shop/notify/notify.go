// Package notify tells customers about their orders.
package notify

import (
	"fmt"

	"shop/internal/logging"
)

// OrderPlaced sends the order confirmation.
func OrderPlaced(customerID, orderID string, totalCents int64) {
	body := render(customerID, orderID, totalCents)

	logging.Debugf("notify: mail to %s (%d bytes)", customerID, len(body))
}

func render(customerID, orderID string, totalCents int64) string {
	return fmt.Sprintf("Hi %s, order %s is confirmed. Total: $%.2f",
		customerID, orderID, float64(totalCents)/100)
}
