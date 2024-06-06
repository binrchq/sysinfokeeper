package serve

import "errors"

type Dialer struct {
}

func NewDialer() *Dialer {
	return &Dialer{}
}

func (s *Dialer) Serve() error {
	return errors.New("1")
}
