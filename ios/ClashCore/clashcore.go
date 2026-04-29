//go:build ios

package clashcore

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/json"
	"errors"
	"io"
	"sync"
)

var (
	mu           sync.Mutex
	isRunning    bool
	config       *Config
	coreInstance *CoreInstance
)

type Config struct {
	HomeDir string `json:"home-dir"`
	Version int    `json:"version"`
}

type CoreInstance struct {
	isInit bool
}

func Start(cfg string) error {
	mu.Lock()
	defer mu.Unlock()

	if isRunning {
		return nil
	}

	var c Config
	if err := json.Unmarshal([]byte(cfg), &c); err != nil {
		return err
	}

	config = &c
	coreInstance = &CoreInstance{isInit: true}
	isRunning = true
	return nil
}

func Stop() error {
	mu.Lock()
	defer mu.Unlock()

	if !isRunning {
		return nil
	}

	coreInstance = nil
	config = nil
	isRunning = false
	return nil
}

func IsRunning() bool {
	mu.Lock()
	defer mu.Unlock()
	return isRunning
}

func Invoke(method string, args string) (string, error) {
	mu.Lock()
	defer mu.Unlock()

	if !isRunning || coreInstance == nil {
		return "", errors.New("core not running")
	}

	switch method {
	case "getProxies":
		return handleGetProxies()
	case "updateConfig":
		return handleUpdateConfig(args)
	case "getConnections":
		return handleGetConnections()
	default:
		return "", nil
	}
}

func handleGetProxies() (string, error) {
	data := map[string]interface{}{
		"proxies": map[string]interface{}{},
		"all":     []string{},
	}
	result, err := json.Marshal(data)
	return string(result), err
}

func handleUpdateConfig(args string) (string, error) {
	return "{}", nil
}

func handleGetConnections() (string, error) {
	data := map[string]interface{}{
		"connections": []interface{}{},
	}
	result, err := json.Marshal(data)
	return string(result), err
}

func GenerateAESKey() ([]byte, error) {
	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		return nil, err
	}
	return key, nil
}

func Encrypt(data []byte, key []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, err
	}

	return gcm.Seal(nonce, nonce, data, nil), nil
}

func Decrypt(data []byte, key []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	nonceSize := gcm.NonceSize()
	if len(data) < nonceSize {
		return nil, errors.New("ciphertext too short")
	}

	nonce, ciphertext := data[:nonceSize], data[nonceSize:]
	return gcm.Open(nil, nonce, ciphertext, nil)
}
