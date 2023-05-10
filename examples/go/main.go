package main		

import (		
	"fmt"		
	"github.com/google/go-cmp/cmp"		
)		

func main() {		
    fmt.Println(cmp.Diff("Hello World", "Hello Go"))		
}
