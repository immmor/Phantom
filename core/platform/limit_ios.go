//go:build ios && cgo

package platform

func ShouldBlockConnection() bool {
	return false
}
