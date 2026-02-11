# Error Handling Checklist

A comprehensive checklist for identifying error handling issues during PR review.

## Swallowed Exceptions

### Empty Catch Blocks

```typescript
// ❌ CRITICAL: Error silently ignored
try {
  await db.transaction(async () => {
    // Critical payment processing
    await transferMoney(from, to, amount);
  });
} catch (error) {
  // Error swallowed! Money could be lost!
}

// ✅ SAFE: Proper error handling
try {
  await db.transaction(async () => {
    await transferMoney(from, to, amount);
  });
} catch (error) {
  logger.error('Payment failed', { error, from, to, amount });
  await notifyUser(from, 'Payment failed');
  throw error; // Re-throw to propagate
}

// ✅ SAFE: Explicit reason for swallowing
try {
  await maybeRemoveFile(tempPath);
} catch (error) {
  // It's OK if file doesn't exist
  if (error.code !== 'ENOENT') throw error;
}
```

**Severity Mapping:**
- **P0**: Critical errors silently ignored (payment, auth, data loss)
- **P1**: Important errors swallowed (API calls, file I/O)
- **P2**: Non-critical errors without proper handling
- **P3**: Minor error handling improvement

### Generic Exception Catching

```typescript
// ❌ BAD: Catches everything including system errors
try {
  await riskyOperation();
} catch (error) {
  // Hides TypeError, ReferenceError, etc.
  logger.info('Something went wrong');
}

// ✅ GOOD: Catch specific exceptions
try {
  await riskyOperation();
} catch (error) {
  if (error instanceof ValidationError) {
    logger.warn('Validation failed', { errors: error.errors });
  } else if (error instanceof NetworkError) {
    logger.error('Network error', { url: error.url });
    throw error; // Re-throw unexpected errors
  } else {
    throw error; // Don't hide unknown errors
  }
}
```

**Severity Mapping:**
- **P0**: Catches all exceptions including fatal system errors
- **P1**: Catches broad exceptions, hides real errors
- **P2**: Overly broad catching for specific case

### Logged But Not Handled

```typescript
// ❌ BAD: Error logged but no recovery action
try {
  await processPayment(amount);
} catch (error) {
  logger.error('Payment failed', { error });
  // What now? User gets no feedback, state corrupted?
}

// ✅ GOOD: Handle the error appropriately
try {
  await processPayment(amount);
} catch (error) {
  logger.error('Payment failed', { error });

  // Rollback partial state
  await order.update({ status: 'payment_failed' });

  // Notify user
  await sendEmail(user.email, 'Payment failed, please retry');

  // Optionally re-throw
  throw new PaymentFailedError('Payment processing failed');
}
```

**Severity Mapping:**
- **P0**: Error logged but data corruption occurs
- **P1**: Error logged but user sees wrong result
- **P2**: Error logged but no meaningful action taken

## Async Error Handling

### Promise Rejection Not Handled

```typescript
// ❌ CRITICAL: No error handler
async function processData() {
  const data = await fetchData(); // What if this fails?
  return process(data);
}

// ✅ SAFE: Proper error handling
async function processData() {
  try {
    const data = await fetchData();
    return process(data);
  } catch (error) {
    logger.error('Failed to fetch data', { error });
    throw new ProcessingError('Data processing failed', { cause: error });
  }
}

// ❌ BAD: Promise without .catch()
fetchData().then(data => processData(data));

// ✅ GOOD: Handle rejection
fetchData()
  .then(data => processData(data))
  .catch(error => {
    logger.error('Processing failed', { error });
    notifyUser('Operation failed');
  });
```

**Severity Mapping:**
- **P0**: Unhandled promise in critical path
- **P1**: Async operations without error handling
- **P2**: Partial async error handling

### Promise.all Error Handling

```typescript
// ❌ BAD: Loses information about other promises
try {
  const [user, orders, stats] = await Promise.all([
    fetchUser(id),
    fetchOrders(id),
    fetchStats(id)
  ]);
  // If fetchUser fails, we lose potentially successful orders/stats
} catch (error) {
  // Only gets first error
}

// ✅ GOOD: Handle all results
const results = await Promise.allSettled([
  fetchUser(id),
  fetchOrders(id),
  fetchStats(id)
]);

const user = results[0].status === 'fulfilled' ? results[0].value : null;
const orders = results[1].status === 'fulfilled' ? results[1].value : [];
const stats = results[2].status === 'fulfilled' ? results[2].value : null;

if (!user) {
  throw new Error('Failed to fetch user');
}

// ✅ GOOD: Use library with better error handling
import { pAll } from 'promise-all-settled-async';
```

**Severity Mapping:**
- **P0**: All parallel operations fail silently
- **P1**: Partial failures not handled
- **P2**: Suboptimal async error handling

### Callback Error Handling

```typescript
// ❌ BAD: Error not checked
fs.readFile('/path/to/file', (err, data) => {
  const content = data.toString(); // Crashes if err is set!
});

// ✅ GOOD: Always check error
fs.readFile('/path/to/file', (err, data) => {
  if (err) {
    logger.error('Failed to read file', { error: err });
    return;
  }
  const content = data.toString();
});
```

## Error Propagation

### Incorrect Error Wrapping

```typescript
// ❌ BAD: Loses original error
try {
  await validateUser(user);
} catch (error) {
  throw new Error('User validation failed');
  // Original error with details lost!
}

// ✅ GOOD: Preserve original error
try {
  await validateUser(user);
} catch (error) {
  throw new Error('User validation failed', { cause: error });
  // Now error.cause has the original
}

// ✅ GOOD: Use error wrapping libraries
import { createError } from 'http-errors';

throw createError(400, 'User validation failed', {
  cause: error
});
```

**Severity Mapping:**
- **P0**: Original error lost, debugging impossible
- **P1**: Error re-thrown without context
- **P2**: Suboptimal error wrapping

### Wrong Error Types

```typescript
// ❌ BAD: Generic error
function divide(a: number, b: number): number {
  if (b === 0) {
    throw new Error('Division by zero');
    // How to catch this specifically?
  }
  return a / b;
}

// ✅ GOOD: Specific error type
class DivisionByZeroError extends Error {
  constructor(message = 'Division by zero') {
    super(message);
    this.name = 'DivisionByZeroError';
  }
}

function divide(a: number, b: number): number {
  if (b === 0) {
    throw new DivisionByZeroError();
  }
  return a / b;
}

// Now can catch specifically
try {
  divide(10, 0);
} catch (error) {
  if (error instanceof DivisionByZeroError) {
    // Handle division by zero
  }
}
```

**Severity Mapping:**
- **P0**: Error type makes handling impossible
- **P1**: Wrong error type prevents proper recovery
- **P2**: Inconsistent error types

### Missing Error Context

```typescript
// ❌ BAD: Error without context
throw new Error('Failed to process');

// ✅ GOOD: Error with context
throw new Error('Failed to process payment', {
  userId: user.id,
  amount: payment.amount,
  currency: payment.currency
});

// ✅ GOOD: Structured error
class PaymentError extends Error {
  constructor(
    message: string,
    public readonly userId: string,
    public readonly amount: number,
    public readonly cause?: Error
  ) {
    super(message);
    this.name = 'PaymentError';
  }
}
```

**Severity Mapping:**
- **P0**: Critical errors with no debugging info
- **P1**: Error messages don't help diagnosis
- **P2**: Missing context in error messages

## Missing Error Scenarios

### Unchecked Null/Undefined

```typescript
// ❌ CRITICAL: Null dereference
function getUserEmail(user: User): string {
  return user.email; // Crashes if user is null!
}

// ✅ GOOD: Null check
function getUserEmail(user: User | null): string {
  if (!user) {
    throw new Error('User not found');
  }
  return user.email;
}

// ✅ GOOD: Optional chaining
function getUserEmail(user: User | null): string | undefined {
  return user?.email; // Returns undefined if user is null
}

// ✅ GOOD: Assertion
function getUserEmail(user: User): string {
  assert(user, 'User is required');
  return user.email;
}
```

**Severity Mapping:**
- **P0**: Null dereference crashes application
- **P1**: Frequent null errors in production
- **P2**: Potential null issues
- **P3**: Minor null safety improvement

### Missing Validation

```typescript
// ❌ BAD: No input validation
function createUser(data: any) {
  await db.insert('users', {
    name: data.name,
    email: data.email
    // What if these are missing or invalid?
  });
}

// ✅ GOOD: Validate input
import { z } from 'zod';

const UserSchema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email()
});

function createUser(data: unknown) {
  const validated = UserSchema.parse(data);
  await db.insert('users', validated);
}
```

**Severity Mapping:**
- **P0**: Missing validation causes security/data issues
- **P1**: Invalid data causes crashes
- **P2**: Inconsistent validation
- **P3**: Minor validation improvement

### Resource Cleanup

```typescript
// ❌ BAD: Resources not cleaned up
async function processFile(path: string) {
  const stream = fs.createReadStream(path);
  const data = await streamToArray(stream);
  // Stream not closed! File handle leaks!
  return data;
}

// ✅ GOOD: Proper cleanup
async function processFile(path: string) {
  const stream = fs.createReadStream(path);
  try {
    const data = await streamToArray(stream);
    return data;
  } finally {
    stream.destroy(); // Always cleanup
  }
}

// ✅ GOOD: Using statement pattern
import { open } from 'fs/promises';

async function processFile(path: string) {
  const file = await open(path, 'r');
  try {
    return await file.readFile();
  } finally {
    await file.close();
  }
}
```

**Severity Mapping:**
- **P0**: Resource leak causes system failure
- **P1**: Resource leak under load
- **P2**: Potential resource leak
- **P3**: Minor cleanup improvement

## Transaction Handling

### Missing Rollback

```typescript
// ❌ CRITICAL: Partial update on failure
async function transferMoney(from: number, to: number, amount: number) {
  await db.update('accounts',
    { balance: db.raw(`balance - ${amount}`) },
    { id: from }
  );

  // What if this fails?
  await db.update('accounts',
    { balance: db.raw(`balance + ${amount}`) },
    { id: to }
  );
  // Money lost if second update fails!
}

// ✅ SAFE: Use transaction
async function transferMoney(from: number, to: number, amount: number) {
  await db.transaction(async (trx) => {
    await trx('accounts')
      .where('id', from)
      .decrement('balance', amount);

    await trx('accounts')
      .where('id', to)
      .increment('balance', amount);
  });
  // Both updates succeed or both fail
}
```

**Severity Mapping:**
- **P0**: Partial updates leave data inconsistent
- **P1**: Missing transaction causes data corruption
- **P2**: Partial transaction handling

## Quick Reference

| Issue | Detection Pattern | Severity |
|-------|------------------|----------|
| Empty Catch | `catch {}` | P0 if critical |
| Generic Catch | `catch (e)` or `catch Exception` | P0 if hides fatal |
| No Async Error | Promise without `.catch()` | P0 in critical path |
| Null Reference | Property access without check | P0 if crashes |
| No Transaction | Multi-step DB ops without txn | P0 if inconsistent |
| No Cleanup | File/DB opened, not closed | P0 if leaks |
