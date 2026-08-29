# WPToolkit

**WPToolkit** is a Windows-focused Lua toolkit for interacting with native Win32 APIs, memory, structures, DLLs, and native functions directly from Lua.

It provides a higher-level interface over low-level native operations, including:

* Win32 API access
* Dynamic DLL/function loading
* Native function calls
* Lua → native callbacks
* Native memory allocation and read/write operations
* Runtime-defined C-style structures
* Native arrays
* Pointer/address manipulation
* x64 native function trampolines and assembly helpers
* Lua runtime/API introspection
* Filesystem and path utilities
* Wide-character/string utilities
* Clipboard access
* Timers
* Loaded DLL inspection

## Building

```bash
git clone https://github.com/anatinesquire40/WPToolkit.git
lar --build WPToolkit -o WPToolkit.lar
```

## Dependencies

* [LuIbexWin](https://github.com/anatinesquire40/LuIbexWin) — provides the Windows and native integration layer used by WPToolkit.
* [Lua-ARchive](https://github.com/anatinesquire40/Lua-ARchive) — provides the runtime environment and module system used to package and run WPToolkit applications as `.lar` files.

WPToolkit is designed to run on the **Lua-ARchive** runtime and use **LuIbexWin** for Windows-specific functionality.

## Basic Usage

```lua
local wp = Toolkit

local Mem = wp.Memory
local StructManager = wp.StructManager
local types = wp.ValueTypes
```

## Calling Win32 APIs

Structures can be described at runtime and passed directly to native functions.

```lua
StructManager:addFormat("RECT", {
    left   = { offset = 0x0, size = 4, type = types.VT_INTEGER },
    top    = { offset = 0x4, size = 4, type = types.VT_INTEGER },
    right  = { offset = 0x8, size = 4, type = types.VT_INTEGER },
    bottom = { offset = 0xC, size = 4, type = types.VT_INTEGER }
})

local SetRect = Mem:GetFunctionFromDll(
    "user32.dll",
    "SetRect",
    types.VT_BOOLEAN,
    {
        "RECT",
        types.VT_INTEGER,
        types.VT_INTEGER,
        types.VT_INTEGER,
        types.VT_INTEGER
    }
)

local rect = StructManager:new("RECT")

assert(SetRect(rect, 345, 293, 223, 533))

print(rect.left, rect.top, rect.right, rect.bottom)
```

The structure is backed by native memory, so `SetRect` can modify it directly and Lua can read the resulting values.

## Native Structures

Structures are defined using offsets, sizes, and value types.

```lua
StructManager:addFormat("Point", {
    x = {
        offset = 0x0,
        size = 4,
        type = types.VT_INTEGER
    },

    y = {
        offset = 0x4,
        size = 4,
        type = types.VT_INTEGER
    }
})

local point = StructManager:new("Point")

point.x = 100
point.y = 200

print(point.x, point.y)
```

Structures can also be parsed from an existing native address:

```lua
local point = StructManager:parseStruct(rawPointer, "Point")

print(point.x, point.y)
```

This allows Lua code to work with native C-style structures without manually calculating every memory offset.

## Calling Functions From DLLs

Native functions can be obtained dynamically from DLLs.

```lua
local add = wp.Memory:GetFunctionFromDll(
    "example.dll",
    "add",
    types.VT_INTEGER,
    {
        types.VT_INTEGER,
        types.VT_INTEGER
    }
)

print(add(10, 20))
```

The return type and argument types are specified using `ValueTypes`.

## Native Callbacks

Lua functions can be passed to native functions as callbacks.

```lua
local callback = function(value)
    print("Received:", value)
    return 42
end
```

A callback signature can be described using `VT_FUNCTION`:

```lua
local func = wp.Memory:GetFunctionFromDll(
    "example.dll",
    "operation",
    types.VT_INTEGER,
    {
        {
            t = types.VT_FUNCTION,
            ret = types.VT_INTEGER,
            argTypes = {
                types.VT_INTEGER,
                types.VT_FLOAT,
                types.VT_DOUBLE,
                types.VT_STRING,
                types.VT_BOOLEAN,
                types.VT_USERDATA
            }
        }
    }
)

print(func(callback))
```

WPToolkit creates the native callback/trampoline needed for native code to invoke the Lua function.

## Native Memory

WPToolkit provides functions for working with native memory and addresses.

```lua
local addr = Mem:CreateAddr(64)

Mem:WriteInteger(addr, 123)
print(Mem:ReadInteger(addr))
```

It also provides operations such as:

```lua
Mem:AddOffset(...)
Mem:SubOffset(...)
Mem:ResolvePointer(...)
Mem:CopyAddr(...)
Mem:CreateAddr(...)
```

and Windows virtual-memory operations:

```lua
Mem.VirtualWin:VirtualAlloc(...)
Mem.VirtualWin:VirtualFree(...)
Mem.VirtualWin:VirtualProtect(...)
```

## Value Types

Native values are described using `ValueTypes`:

```lua
types.VT_INTEGER
types.VT_INTEGER8
types.VT_INTEGER16
types.VT_INTEGER32
types.VT_INTEGER64
types.VT_FLOAT
types.VT_DOUBLE
types.VT_BOOLEAN
types.VT_STRING
types.VT_USERDATA
types.VT_FUNCTION
types.VT_ARRAY
```

These types are used throughout the memory, structure, and native-function systems.

## Example: Native Structure + Callback

A native function can pass a structure pointer into a Lua callback:

```lua
StructManager:addFormat("Point", {
    x = { offset = 0x0, size = 4, type = types.VT_INTEGER },
    y = { offset = 0x4, size = 4, type = types.VT_INTEGER }
})

local function callback(rawPoint)
    local point = StructManager:parseStruct(rawPoint, "Point")

    return (point.x + point.y) // 4
end
```

The native side can provide the pointer, while Lua interprets it using the structure definition.

## What WPToolkit Provides

```text
WPToolkit
├── Memory
│   ├── Native memory
│   ├── Address manipulation
│   ├── DLL/function lookup
│   └── Virtual memory
│
├── NativeFunctionManager
│   ├── Native calls
│   ├── Lua callbacks
│   ├── Trampolines
│   └── x64 assembly helpers
│
├── StructManager
│   ├── C-style structures
│   ├── Native memory views
│   └── Structure formats
│
├── ArrayManager
│   └── Native arrays
│
├── LuaInfo
│   └── Lua runtime/API information
│
├── FileManager
├── PathManager
├── StringManager
├── WideCharManager
├── LoadedDlls
├── Clipboard
└── LuaTimer
```

## Requirements

WPToolkit is intended for **64-bit Windows** and uses native Windows functionality.

Required components:

* **LuIbexWin**
* **Lua-ARchive runtime**

WPToolkit is designed to operate within the Lua-ARchive ecosystem and can be packaged as a `.lar` application.

> **Warning:** WPToolkit exposes low-level native memory and function-call functionality. Incorrect types, addresses, structure layouts, or function signatures can corrupt memory or crash the process.
