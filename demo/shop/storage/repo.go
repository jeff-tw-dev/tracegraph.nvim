// Package storage persists orders.
package storage

import (
	"fmt"
	"sync"

	"shop/internal/logging"
	"shop/service"
)

// Repo is a pretend database handle.
type Repo struct {
	path string
	mu   sync.Mutex
	seq  int
	rows map[string]*service.Order
}

func NewRepo(path string) *Repo {
	return &Repo{path: path, rows: make(map[string]*service.Order)}
}

// NextID hands out the next order id.
func (r *Repo) NextID() string {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.seq++
	return fmt.Sprintf("ord-%04d", r.seq)
}

// Save writes one order to the database.
func (r *Repo) Save(o *service.Order) error {
	logging.Debugf("storage: saving %s to %s", o.ID, r.path)

	r.mu.Lock()
	r.rows[o.ID] = o
	rows := len(r.rows)
	r.mu.Unlock()

	logging.Debugf("storage: %s saved, %d rows total", o.ID, rows)
	return nil
}
