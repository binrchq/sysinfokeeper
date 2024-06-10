package serve

import (
	"errors"
)

type Dialer struct {
}

func NewDialer() *Dialer {
	return &Dialer{}
}

func (s *Dialer) Serve() error {
	//协程处理拨号任务
	return errors.New("1")
}
