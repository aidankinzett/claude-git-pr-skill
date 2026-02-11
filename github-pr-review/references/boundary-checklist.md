# Boundary Condition Checklist

A comprehensive checklist for identifying boundary condition issues during PR review.

## Null/Undefined Handling

### Null Reference Exceptions

```typescript
// ❌ CRITICAL: Null dereference
function getUserEmail(user: User | null): string {
  return user.email; // Crashes if user is null!
}

// ✅ SAFE: Null check
function getUserEmail(user: User | null): string | null {
  if (!user) return null;
  return user.email;
}

// ✅ SAFE: Optional chaining
function getUserEmail(user: User | null): string | undefined {
  return user?.email;
}

// ✅ SAFE: Null assertion (when you're sure)
function getUserEmail(user: User): string {
  return user!.email; // Asserts non-null
}
```

**Severity Mapping:**
- **P0**: Null dereference crashes application immediately
- **P1**: Frequent null errors in expected scenarios
- **P2**: Null possible but rare
- **P3**: Minor null safety improvement

### Undefined vs Null

```typescript
// ❌ BAD: Confuses undefined and null
function hasValue(value: any): boolean {
  return value != null; // True for both null and undefined!
}

// ✅ GOOD: Explicit checks
function hasValue(value: any): boolean {
  return value !== null && value !== undefined;
}

// ✅ GOOD: Nullish coalescing
const value = input ?? 'default'; // Only null/undefined
const value = input || 'default'; // Also 0, '', false

// ❌ BAD: Loose equality
if (value == null) { } // Matches both null and undefined

// ✅ GOOD: Strict equality
if (value === null || value === undefined) { }
```

**Severity Mapping:**
- **P0**: Type coercion causes critical failures
- **P1**: Undefined treated as null incorrectly
- **P2**: Inconsistent null/undefined handling

### Default Values

```typescript
// ❌ BAD: Missing defaults for optional parameters
function greet(name?: string) {
  return `Hello, ${name.toUpperCase()}`; // Crashes if name is undefined!
}

// ✅ GOOD: Default value
function greet(name: string = 'Guest') {
  return `Hello, ${name.toUpperCase()}`;
}

// ✅ GOOD: Nullish coalescing
function greet(name?: string) {
  const actualName = name ?? 'Guest';
  return `Hello, ${actualName.toUpperCase()}`;
}

// ❌ BAD: Destructuring without defaults
function processUser(user: { name?: string; age?: number }) {
  const { name, age } = user; // Both could be undefined!
}

// ✅ GOOD: Destructuring with defaults
function processUser(user: { name?: string; age?: number }) {
  const { name = 'Unknown', age = 0 } = user;
}
```

**Severity Mapping:**
- **P0**: Critical operations fail with undefined
- **P1**: User-facing features break without defaults
- **P2**: Inconsistent default value handling

## Empty Collection Handling

### Empty Arrays

```typescript
// ❌ CRITICAL: Accessing empty array
function getFirstItem(items: any[]): any {
  return items[0]; // Returns undefined if empty!
}

function getFirstItem(items: any[]): any {
  return items[0].name; // Crashes if empty!
}

// ✅ SAFE: Check length first
function getFirstItem(items: any[]): any | undefined {
  if (items.length === 0) return undefined;
  return items[0];
}

// ✅ SAFE: Optional chaining
function getFirstItem(items: any[]): any {
  return items[0]?.name; // Returns undefined if empty
}

// ✅ SAFE: Throw meaningful error
function getFirstItem(items: any[]): any {
  if (items.length === 0) {
    throw new Error('Cannot get first item from empty array');
  }
  return items[0];
}
```

**Severity Mapping:**
- **P0**: Empty array crashes critical operation
- **P1**: Empty array causes incorrect results
- **P2**: Empty array edge case not tested
- **P3**: Minor empty handling improvement

### Empty Strings

```typescript
// ❌ BAD: Assumes string has content
function processEmail(email: string): string {
  const [local, domain] = email.split('@');
  return local; // Could be empty string!
}

// ✅ GOOD: Validate content
function processEmail(email: string): string {
  if (!email.trim()) {
    throw new Error('Email cannot be empty');
  }
  const [local, domain] = email.split('@');
  if (!local || !domain) {
    throw new Error('Invalid email format');
  }
  return local;
}

// ❌ BAD: Empty string vs null confusion
if (email) { } // False for both '' and null
if (email !== null) { } // True for '' but false for null

// ✅ GOOD: Be explicit
if (email !== null && email !== '') { }
if (email?.trim()) { } // Handles null, undefined, and whitespace
```

**Severity Mapping:**
- **P0**: Empty string causes security/validation bypass
- **P1**: Empty string produces wrong output
- **P2**: Empty string edge case

### Zero Values

```typescript
// ❌ CRITICAL: Division by zero
function calculateAverage(sum: number, count: number): number {
  return sum / count; // NaN or Infinity if count is 0!
}

// ✅ SAFE: Check for zero
function calculateAverage(sum: number, count: number): number {
  if (count === 0) {
    throw new Error('Cannot calculate average of zero items');
  }
  return sum / count;
}

// ❌ BAD: Zero as falsy causes bugs
function shouldProcess(value: number): boolean {
  return value ? process(value) : false; // 0 is falsy!
}

// ✅ GOOD: Explicit check
function shouldProcess(value: number): boolean {
  if (value !== 0) {
    return process(value);
  }
  return false;
}

// ❌ BAD: Modulo with zero
function chunk<T>(arr: T[], size: number): T[][] {
  return arr.reduce((chunks, item, i) => {
    const chunkIndex = Math.floor(i / size); // NaN if size is 0!
    // ...
  }, []);
}

// ✅ GOOD: Validate input
function chunk<T>(arr: T[], size: number): T[][] {
  if (size <= 0) {
    throw new Error('Chunk size must be positive');
  }
  // ...
}
```

**Severity Mapping:**
- **P0**: Division by zero crashes application
- **P1**: Zero produces incorrect calculation
- **P2**: Zero edge case not handled
- **P3**: Minor zero handling improvement

## Off-By-One Errors

### Loop Boundaries

```typescript
// ❌ BAD: Off-by-one error
function sumRange(start: number, end: number): number {
  let sum = 0;
  for (let i = start; i <= end; i++) { // Should be < not <=!
    sum += i;
  }
  return sum;
}

// sumRange(1, 5) returns 15 (1+2+3+4+5)
// If meant to be exclusive of end, should be <

// ✅ GOOD: Be explicit about inclusivity
function sumRange(start: number, endInclusive: number): number {
  let sum = 0;
  for (let i = start; i <= endInclusive; i++) {
    sum += i;
  }
  return sum;
}

function sumRangeExclusive(start: number, endExclusive: number): number {
  let sum = 0;
  for (let i = start; i < endExclusive; i++) {
    sum += i;
  }
  return sum;
}
```

**Severity Mapping:**
- **P0**: Off-by-one causes data loss/corruption
- **P1**: Off-by-one causes incorrect results
- **P2**: Potential off-by-one in edge cases
- **P3**: Minor boundary improvement

### Array Length vs Index

```typescript
// ❌ BAD: Length vs index confusion
function getLastItem<T>(arr: T[]): T {
  return arr[arr.length]; // Undefined! Should be length - 1
}

// ✅ GOOD: Correct index
function getLastItem<T>(arr: T[]): T {
  return arr[arr.length - 1];
}

// ❌ BAD: Substring off-by-one
function getFirstNChars(str: string, n: number): string {
  return str.substring(0, n); // OK for substring
}

function getFirstNChars(str: string, n: number): string {
  return str.substr(0, n); // Deprecated
}

// ❌ BAD: Copy array with slice
function copyArray<T>(arr: T[]): T[] {
  return arr.slice(0, arr.length); // Works but unnecessary
}

function copyArray<T>(arr: T[]): T[] {
  return arr.slice(); // Simpler
}

// ❌ BAD: Pagination off-by-one
function getPaginatedItems(page: number, pageSize: number) {
  const offset = page * pageSize; // Wrong! Should be (page - 1)
  const limit = pageSize;
  return db.query('SELECT * FROM items LIMIT $1 OFFSET $2', [limit, offset]);
}

// ✅ GOOD: Correct pagination (assuming page starts at 1)
function getPaginatedItems(page: number, pageSize: number) {
  const offset = (page - 1) * pageSize;
  const limit = pageSize;
  return db.query('SELECT * FROM items LIMIT $1 OFFSET $2', [limit, offset]);
}
```

**Severity Mapping:**
- **P0**: Index out of bounds crashes app
- **P1**: Length confusion causes bugs
- **P2**: Potential length edge case

## Numeric Limits

### Integer Overflow

```typescript
// ❌ BAD: Unbounded arithmetic can overflow
function calculateTotal(prices: number[]): number {
  return prices.reduce((sum, price) => sum + price, 0);
  // Can overflow with many large numbers!
}

// ✅ GOOD: Check for overflow
function calculateTotal(prices: number[]): number {
  const max = Number.MAX_SAFE_INTEGER;
  let sum = 0;
  for (const price of prices) {
    if (sum > max - price) {
      throw new Error('Numeric overflow');
    }
    sum += price;
  }
  return sum;
}

// ✅ GOOD: Use BigInt for large numbers
function calculateTotal(prices: bigint[]): bigint {
  return prices.reduce((sum, price) => sum + price, 0n);
}
```

**Severity Mapping:**
- **P0**: Overflow causes security vulnerability
- **P1**: Overflow causes data corruption
- **P2**: Potential overflow in edge cases

### Floating Point Precision

```typescript
// ❌ BAD: Float equality comparison
function areEqual(a: number, b: number): boolean {
  return a === b; // Often false due to precision!
}

// 0.1 + 0.2 === 0.3 is false!

// ✅ GOOD: Epsilon comparison
function areEqual(a: number, b: number, epsilon = 1e-10): boolean {
  return Math.abs(a - b) < epsilon;
}

// ❌ BAD: Currency with float
function calculateTotal(prices: number[]): number {
  return prices.reduce((sum, price) => sum + price, 0);
  // Precision loss with currency!
}

// ✅ GOOD: Use integer cents
function calculateTotal(prices: number[]): number {
  return prices.reduce((sum, price) => sum + price, 0);
  // Prices in cents, not dollars
}

// Or use decimal library
import Decimal from 'decimal.js';
function calculateTotal(prices: string[]): Decimal {
  return prices.reduce((sum, price) => sum.plus(price), new Decimal(0));
}
```

**Severity Mapping:**
- **P0**: Float comparison causes security issue
- **P1**: Float precision causes incorrect results
- **P2**: Potential float precision edge case

### Number Conversion

```typescript
// ❌ BAD: String to number without validation
function parseAmount(input: string): number {
  return parseInt(input); // NaN if invalid!
}

// ✅ GOOD: Validate conversion
function parseAmount(input: string): number {
  const num = parseInt(input, 10);
  if (isNaN(num)) {
    throw new Error(`Invalid number: ${input}`);
  }
  return num;
}

// ❌ BAD: Missing radix
function parseHex(input: string): number {
  return parseInt(input); // Assumes decimal!
}

// ✅ GOOD: Always specify radix
function parseHex(input: string): number {
  return parseInt(input, 16); // Explicit radix
}
```

**Severity Mapping:**
- **P0**: Invalid number crashes operation
- **P1**: Conversion produces NaN unexpectedly
- **P2**: Potential conversion edge case

## String Boundaries

### Unicode/Encoding

```typescript
// ❌ BAD: Assumes 1 char = 1 byte
function getStringBytes(str: string): number {
  return str.length; // Wrong for multi-byte characters!
}

// ✅ GOOD: Use TextEncoder
function getStringBytes(str: string): number {
  return new TextEncoder().encode(str).length;
}

// ❌ BAD: String operations on emoji
function truncate(str: string, maxLength: number): string {
  return str.substring(0, maxLength); // May cut emoji in half!
}

// ✅ GOOD: Use grapheme-aware library
import { substring } from 'grapheme-splitter';

function truncate(str: string, maxLength: number): string {
  return substring(str, 0, maxLength);
}
```

**Severity Mapping:**
- **P0**: Encoding causes data corruption
- **P1**: Unicode causes incorrect length/index
- **P2**: Potential unicode edge case

## Date/Time Boundaries

### Timezone Issues

```typescript
// ❌ BAD: Assumes local timezone
function isToday(date: Date): boolean {
  const today = new Date();
  return date.getDate() === today.getDate() &&
         date.getMonth() === today.getMonth() &&
         date.getFullYear() === today.getFullYear();
  // Fails across timezone boundaries!
}

// ✅ GOOD: Use UTC or timezone-aware comparison
function isToday(date: Date): boolean {
  const today = new Date();
  return date.toDateString() === today.toDateString();
}

// ❌ BAD: Date arithmetic across boundaries
function addDay(date: Date): Date {
  return new Date(date.getTime() + 86400000); // Wrong during DST!
}

// ✅ GOOD: Use date library
import { addDays } from 'date-fns';

function addDay(date: Date): Date {
  return addDays(date, 1);
}
```

**Severity Mapping:**
- **P0**: Timezone causes data errors (financial, legal)
- **P1**: Timezone causes incorrect display
- **P2**: Potential timezone edge case

## Quick Reference

| Boundary | Detection Pattern | Severity |
|----------|------------------|----------|
| Null Dereference | Property access without `?.` or check | P0 if crashes |
| Empty Array | `arr[0]` without length check | P0 if crashes |
| Division by Zero | `/ x` where x could be 0 | P0 if crashes |
| Off-by-One | `<` vs `<=`, `length` vs `length-1` | P0 if corrupts data |
| Integer Overflow | Unbounded arithmetic | P0 if security |
| Float Equality | `a === b` for floats | P1 if incorrect results |
| Unicode | `str.length` for bytes | P1 if wrong length |
| Timezone | Date arithmetic without library | P1 if wrong date |
