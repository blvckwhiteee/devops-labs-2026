package domain

import "context"

type ReadinessChecker interface {
	Ping(ctx context.Context) error
}
