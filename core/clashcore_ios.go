//go:build ios && cgo

package clashcore

/*
#cgo LDFLAGS: -L${SRCDIR}/../../libclash/ios
#cgo ios LDFLAGS: -lclashcore -framework Foundation -framework NetworkExtension
#include <stdlib.h>
#include <stdint.h>

extern void FreeString(char *s);
extern char *InvokeMethod(char *method, char *args);
*/
import "C"
import (
	"encoding/json"
	"sync"
	"unsafe"
)

var (
	mu       sync.Mutex
	instance *ClashCore
)

type ClashCore struct {
	isRunning bool
}

func NewClashCore() *ClashCore {
	mu.Lock()
	defer mu.Unlock()
	if instance == nil {
		instance = &ClashCore{}
	}
	return instance
}

func (c *ClashCore) Start(config string) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	cdata := C.CString(`{"method":"start","config":` + config + `}`)
	defer C.free(unsafe.Pointer(cdata))

	result := C.InvokeMethod(cdata, nil)
	if result == nil {
		c.isRunning = true
		return nil
	}
	defer C.free(unsafe.Pointer(result))

	return nil
}

func (c *ClashCore) Stop() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	cdata := C.CString(`{"method":"stop"}`)
	defer C.free(unsafe.Pointer(cdata))

	C.InvokeMethod(cdata, nil)
	c.isRunning = false
	return nil
}

func (c *ClashCore) IsRunning() bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.isRunning
}

func (c *ClashCore) Invoke(method string, args interface{}) (string, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	argBytes, err := json.Marshal(args)
	if err != nil {
		return "", err
	}

	msg := map[string]interface{}{
		"method": method,
		"args":   argBytes,
	}
	msgBytes, _ := json.Marshal(msg)

	cdata := C.CString(string(msgBytes))
	defer C.free(unsafe.Pointer(cdata))

	result := C.InvokeMethod(cdata, nil)
	if result == nil {
		return "", nil
	}
	defer C.free(unsafe.Pointer(result))

	return C.GoString(result), nil
}

func FreeResult(s *C.char) {
	if s != nil {
		C.free(unsafe.Pointer(s))
	}
}
