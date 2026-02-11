# SOLID Principles Checklist

A comprehensive checklist for identifying SOLID principle violations in code during PR review.

## Single Responsibility Principle (SRP)

A class/module should have one, and only one, reason to change.

### Red Flags

#### God Classes
```typescript
// ❌ BAD: Does too many things
class UserService {
  createUser(data: any) { /* ... */ }
  validateEmail(email: string) { /* ... */ }
  sendWelcomeEmail(user: User) { /* ... */ }
  logUserAction(user: User) { /* ... */ }
  calculateUserStats(user: User) { /* ... */ }
  backupUserData(user: User) { /* ... */ }
}

// ✅ GOOD: Separated concerns
class UserService {
  constructor(
    private emailValidator: EmailValidator,
    private emailService: EmailService,
    private logger: Logger,
    private statsService: StatsService
  ) {}
  createUser(data: any) { /* orchestrates, doesn't do everything */ }
}
```

#### Method Names
```typescript
// ❌ BAD: "and" indicates multiple responsibilities
function fetchAndValidateAndSave(data: any) { }

function parseAndTransformAndExport(input: string) { }

// ✅ GOOD: Single purpose
function saveValidatedData(data: any) { }
function exportTransformedData(input: string) { }
```

#### Change Reasons
Ask: "How many reasons exist to change this class?"

- **P0**: 5+ distinct reasons (e.g., DB schema change, validation rules, email template, logging format, analytics)
- **P1**: 3-4 distinct reasons
- **P2**: 2 distinct reasons
- **P3**: Minor cohesion issues

## Open/Closed Principle (OCP)

Software entities should be open for extension, but closed for modification.

### Red Flags

#### Hard-coded Dependencies
```typescript
// ❌ BAD: Need to modify to add new payment type
class PaymentProcessor {
  processPayment(type: string, amount: number) {
    if (type === 'credit-card') { /* ... */ }
    else if (type === 'paypal') { /* ... */ }
    else if (type === 'bank-transfer') { /* ... */ }
    // Must modify here for new payment type
  }
}

// ✅ GOOD: Add new types without modification
interface PaymentMethod {
  process(amount: number): void;
}

class PaymentProcessor {
  private methods: Map<string, PaymentMethod>;

  registerMethod(name: string, method: PaymentMethod) {
    this.methods.set(name, method);
  }

  processPayment(type: string, amount: number) {
    this.methods.get(type)?.process(amount);
  }
}
```

#### Switch/If Chains
```typescript
// ❌ BAD: OCP violation
function getDiscount(userType: string): number {
  if (userType === 'guest') return 0;
  else if (userType === 'member') return 0.1;
  else if (userType === 'premium') return 0.2;
  // Must modify for new user type
}

// ✅ GOOD: Use strategy pattern
interface DiscountStrategy {
  getDiscount(): number;
}
```

## Liskov Substitution Principle (LSP)

Subtypes must be substitutable for their base types.

### Red Flags

#### Not Implemented Exceptions
```typescript
// ❌ BAD: Violates LSP
class Rectangle {
  setWidth(width: number) { }
  setHeight(height: number) { }
  area() { return this.width * this.height; }
}

class Square extends Rectangle {
  setWidth(width: number) {
    this.width = width;
    this.height = width; // Breaks rectangle behavior!
  }
}

// ✅ GOOD: Separate abstractions
interface Shape {
  area(): number;
}
```

#### Contract Violations
```typescript
// ❌ BAD: Weakens postcondition
class Repository {
  find(id: number): Entity | null {
    // Guaranteed to return entity if exists
  }
}

class CachedRepository extends Repository {
  find(id: number): Entity | null {
    // May return null even if exists (cache miss)
  }
}
```

## Interface Segregation Principle (ISP)

Clients shouldn't depend on interfaces they don't use.

### Red Flags

#### Fat Interfaces
```typescript
// ❌ BAD: Forces unused methods
interface Worker {
  work(): void;
  eat(): void;
  sleep(): void;
}

class Robot implements Worker {
  work() { /* ... */ }
  eat() { throw new Error("Robots don't eat!"); }
  sleep() { throw new Error("Robots don't sleep!"); }
}

// ✅ GOOD: Segregated interfaces
interface Workable {
  work(): void;
}

interface Biological {
  eat(): void;
  sleep(): void;
}

class Robot implements Workable {
  work() { /* ... */ }
}
```

#### Empty Implementations
- Look for methods with empty bodies just to satisfy interface
- Look for methods throwing "not supported" exceptions
- **P0**: 5+ forced unused methods
- **P1**: 3-4 forced unused methods

## Dependency Inversion Principle (DIP)

Depend on abstractions, not concretions.

### Red Flags

#### Direct Database Dependencies
```typescript
// ❌ BAD: High-level module depends on low-level details
class UserProcessor {
  constructor(
    private db: PostgresDatabase // Concrete dependency
  ) {}

  processUser(id: number) {
    const user = this.db.query('SELECT * FROM users WHERE id = $1', [id]);
    // Business logic here
  }
}

// ✅ GOOD: Depends on abstraction
interface Database {
  query(sql: string, params: any[]): Promise<any>;
}

class UserProcessor {
  constructor(
    private db: Database // Abstract dependency
  ) {}
}
```

#### New Operator
```typescript
// ❌ BAD: Creates concrete dependency
class OrderService {
  createOrder(data: any) {
    const validator = new OrderValidator(); // Tight coupling
    validator.validate(data);
  }
}

// ✅ GOOD: Inject dependency
class OrderService {
  constructor(private validator: OrderValidator) {}

  createOrder(data: any) {
    this.validator.validate(data);
  }
}
```

## Additional Code Smells

### Duplicated Code
- **P0**: Same logic copied 5+ times with variations
- **P1**: Same logic copied 3-4 times
- **P2**: Same logic copied 2 times

### Primitive Obsession
```typescript
// ❌ BAD: Domain concepts as primitives
function sendEmail(email: string, phone: string) { }

// ✅ GOOD: Domain types
type Email = string & { readonly __brand: unique symbol };
type Phone = string & { readonly __brand: unique symbol };

function sendEmail(email: Email, phone: Phone) { }
```

### Long Methods
- **P0**: 100+ lines
- **P1**: 50-99 lines with multiple responsibilities
- **P2**: 30-49 lines

### Feature Envy
```typescript
// ❌ BAD: Method envies another class
class Order {
  calculateDiscount(customer: Customer) {
    if (customer.getLoyaltyPoints() > 1000 &&
        customer.getOrders().length > 10 &&
        customer.getRegion() === 'VIP') {
      // This logic belongs to Customer, not Order
    }
  }
}

// ✅ GOOD: Logic in appropriate class
class Order {
  calculateDiscount(customer: Customer) {
    return customer.calculateOrderDiscount();
  }
}
```

## Quick Reference Table

| Principle | Key Question | Common Violation |
|-----------|--------------|------------------|
| SRP | How many reasons to change? | God class, "and" in names |
| OCP | Must I modify to extend? | if/else chains, hard-coded types |
| LSP | Can I substitute subtype? | Not implemented, weakened contract |
| ISP | Does client use all methods? | Fat interface, empty implementations |
| DIP | Do I depend on concrete? | `new` in constructor, direct DB access |
