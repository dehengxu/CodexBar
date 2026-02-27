# Sources — CodexBarMacros

<think>
Let me analyze this module carefully to understand what it does and how to document it.

## Understanding the Module

This is a Swift Macro plugin module called `CodexBarMacros`. It provides three macros:

1. **ProviderDescriptorRegistrationMacro** - A `PeerMacro` that registers a provider descriptor with the registry
2. **ProviderDescriptorDefinitionMacro** - A `MemberMacro` that generates a static `descriptor` property
3. **ProviderImplementationRegistrationMacro** - A `PeerMacro` that registers a provider implementation

### Key Components:

1. **ProviderMacroError** - Contains error definitions and diagnostic helpers for various validation errors
2. **ProviderMacroIntrospection** - Contains helper functions to inspect type declarations
3. **The three macro implementations**
4. **CodexBarMacroPlugin** - The main plugin entry point

### The Macros:

**@ProviderDescriptorRegistration** (PeerMacro)
- Must be attached to a struct, class, or enum
- Requires either `static let descriptor` or `static func makeDescriptor()` to exist
- Generates code that registers the descriptor with `ProviderDescriptorRegistry.register()`

**@ProviderDescriptorDefinition** (MemberMacro)
- Must be attached to a struct, class, or enum
- Requires `static func makeDescriptor()` to exist
- Generates `public static let descriptor: ProviderDescriptor = Self.makeDescriptor()`
- Errors if `static let descriptor` already exists

**@ProviderImplementationRegistration** (PeerMacro)
- Must be attached to a struct, class, or enum
- Requires an accessible init() (either explicit or synthesizable)
- Generates code that registers the type with `ProviderImplementationRegistry.register()`

### Execution Flow:

When a developer uses these macros:


1. The compiler invokes the macro expansion
2. The macro inspects the declaration it's attached to
3. Validation runs to ensure requirements are met
4. Either peer declarations or new member declarations get generated
5. If validation fails, the macro emits diagnostic errors and returns empty

### Architecture:

The macros follow a validation-first pattern where they validate requirements before generating any code. The introspection utilities allow each macro to examine the declaration it processes, and peer macros generate declarations alongside the original one while member macros add new members to the type.

Now I should document how developers use these macros in practice, starting with examples like defining a provider type with a descriptor and implementation, then showing how the macros transform that into registered code.
</think>

# CodexBarMacros

A Swift macro plugin that provides three attribute macros for registering providers and their descriptors with the CodexBar dependency injection system.

## Overview

This module defines Swift macros that automate the registration of provider types with the CodexBar dependency injection framework. Instead of manually writing registration boilerplate, you can attach attributes to your types and let the macros generate the appropriate registration code at compile time.

The macros handle three aspects of provider registration:

1. **Descriptor Registration** — Registers a type's `ProviderDescriptor` with the global registry
2. **Descriptor Definition** — Generates a `static let descriptor` property from a `makeDescriptor()` method
3. **Implementation Registration** — Registers a type as a concrete implementation provider

## Macros

### @ProviderDescriptorDefinition

A **MemberMacro** that generates a static `descriptor` property for types that implement `makeDescriptor()`.

```swift
@ProviderDescriptorDefinition
struct MyProvider {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(name: "MyProvider", ...)
    }
}
```

Expands to:

```swift
struct MyProvider {
    public static let descriptor: ProviderDescriptor = Self.makeDescriptor()
}
```

**Requirements:**
- Must be attached to a `struct`, `class`, or `enum`
- The type must declare a static `makeDescriptor()` method

---

### @ProviderDescriptorRegistration

A **PeerMacro** that registers the type's descriptor with `ProviderDescriptorRegistry`.

```swift
@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
struct MyProvider {
    static func makeDescriptor() -> ProviderDescriptor { ... }
}
```

Expands to add a private property that performs registration:

```swift
private let _CodexBarDescriptorRegistration_MyProvider = 
    ProviderDescriptorRegistry.register(MyProvider.descriptor)
```

**Requirements:**
- Must be attached to a `struct`, `class`, or `enum`
- The type must have either `static let descriptor` or `static func makeDescriptor()`

---

### @ProviderImplementationRegistration

A **PeerMacro** that registers the type as a concrete implementation provider.

```swift
@ProviderImplementationRegistration
struct DatabaseProvider: Provider {
    let connectionString: String
    
    init(connectionString: String = "default") {
        self.connectionString = connectionString
    }
}
```

Expands to:

```swift
private let _CodexBarImplementationRegistration_DatabaseProvider = 
    ProviderImplementationRegistry.register(DatabaseProvider())
```

**Requirements:**
- Must be attached to a `struct`, `class`, or `enum`
- The type must have an accessible initializer (either explicit with no arguments, or synthesizable with all properties having default values)

---

## Combined Usage

The macros are typically used together:

```swift
@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
final class UserServiceProvider: Provider {
    typealias Dependency = UserRepository & Logger
    
    private let repository: UserRepository
    private let logger: Logger
    
    init(repository: UserRepository, logger: Logger) {
        self.repository = repository
        self.logger = logger
    }
    
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            name: "UserService",
            dependencyType: (UserRepository.self, Logger.self),
            factory: { UserServiceProvider(repository: $0, logger: $1) }
        )
    }
}

@ProviderImplementationRegistration
final class DefaultUserRepository: UserRepository { ... }
```

## Internal Components

### ProviderMacroError

Defines compile-time error messages for common misuse scenarios:

| Error | Cause |
|-------|-------|
| `unsupported_target` | Macro attached to something other than struct/class/enum |
| `missing_descriptor` | `@ProviderDescriptorRegistration` on type without descriptor |
| `missing_make_descriptor` | `@ProviderDescriptorDefinition` on type without `makeDescriptor()` |
| `duplicate_descriptor` | `@ProviderDescriptorDefinition` on type that already has `static let descriptor` |
| `missing_init` | `@ProviderImplementationRegistration` on type without accessible init |

### ProviderMacroIntrospection

Helper functions that inspect type declarations to determine:

- Whether a type declares `static let descriptor`
- Whether a type declares `static func makeDescriptor()`
- Whether a type has an accessible zero-argument initializer
- Whether a struct/class can have a default initializer synthesized

## Architecture

```mermaid
flowchart TD
    subgraph Macros
        PD[ProviderDescriptorDefinitionMacro]
        PR[ProviderDescriptorRegistrationMacro]
        PI[ProviderImplementationRegistrationMacro]
    end
    
    subgraph Introspection
        TI[ProviderMacroIntrospection]
        TE[ProviderMacroError]
    end
    
    PD -->|validates via| TI
    PR -->|validates via| TI
    PI -->|validates via| TI
    
    PD -->|emits errors via| TE
    PR -->|emits errors via| TE
    PI -->|emits errors via| TE
    
    PD -->|"adds member"| Decl[Generated: static let descriptor]
    PR -->|"adds peer"| Reg1[ProviderDescriptorRegistry.register]
    PI -->|"adds peer"| Reg2[ProviderImplementationRegistry.register]
```

## Error Handling

When macros encounter invalid usage, they emit Swift compiler diagnostics and return empty expansions. This means:

- Invalid macro applications produce compile errors, not silent failures
- The original code remains unchanged when errors occur
- Multiple errors can be reported if applicable

For example, applying `@ProviderDescriptorRegistration` to a protocol:

```swift
@ProviderDescriptorRegistration
protocol MyProvider { }  // Error: @ProviderDescriptorRegistration must be attached to a struct, class, or enum.
```