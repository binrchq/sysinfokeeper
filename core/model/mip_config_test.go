package model

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestMipChecksum(t *testing.T) {
	c := MipConfig{}
	c1 := c.GenChecksum()
	t.Log(c1)
	c.Device = "test"
	c2 := c.GenChecksum()
	t.Log(c2)
	c.BSCBWLimit = 10
	c3 := c.GenChecksum()
	t.Log(c3)
	assert.NotEqual(t, c1, c2, "关键字段改变, 修改校验和")
	assert.Equal(t, c2, c3, "非关键字段不改变校验和")
}
