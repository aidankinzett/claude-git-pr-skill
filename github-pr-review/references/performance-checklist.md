# Performance Checklist

A comprehensive checklist for identifying performance issues during PR review.

## Database Query Issues

### N+1 Query Problem

#### Detection Pattern
```typescript
// ❌ CRITICAL: N+1 query problem
async function getUsersWithOrders() {
  const users = await db.query('SELECT * FROM users'); // 1 query

  const result = [];
  for (const user of users) { // N queries!
    const orders = await db.query(
      'SELECT * FROM orders WHERE user_id = $1',
      [user.id]
    );
    result.push({ ...user, orders });
  }
  // Total: 1 + N queries

  return result;
}

// ✅ SAFE: Eager loading with JOIN
async function getUsersWithOrders() {
  const result = await db.query(`
    SELECT u.*, o.* FROM users u
    LEFT JOIN orders o ON o.user_id = u.id
  `); // 1 query!
  return result;
}

// ✅ SAFE: Eager loading with ORM
const users = await User.findAll({
  include: [{ model: Order }] // Generates JOIN
});
```

**Severity Mapping:**
- **P0**: N+1 in hot path (API endpoints, batch jobs)
- **P1**: N+1 in user-facing features
- **P2**: N+1 in less critical paths
- **P3**: Potential N+1 with small datasets

#### Detection Checklist
- [ ] Query inside loop (especially `forEach`, `for`, `while`)
- [ ] Lazy loading triggered in iteration
- [ ] Multiple similar queries in sequence
- [ ] Missing `include`, `join`, or `eager` option

### Missing Indexes

```sql
-- ❌ SLOW: Full table scan
SELECT * FROM users WHERE email = '...';
-- Without index on email, scans entire table!

-- ✅ FAST: Index seek
CREATE INDEX idx_users_email ON users(email);
```

**Severity Mapping:**
- **P0**: Query on large table (>1M rows) without index
- **P1**: Query on medium table (>100K rows) without index
- **P2**: Query that could benefit from index
- **P3**: Minor indexing opportunity

### Inefficient Queries

```typescript
// ❌ BAD: SELECT * returns unnecessary data
const users = await db.query('SELECT * FROM users LIMIT 1000');
// Returns all columns, including huge JSON fields!

// ✅ GOOD: Select only needed columns
const users = await db.query(`
  SELECT id, name, email FROM users LIMIT 1000
`);

// ❌ BAD: Multiple queries that could be one
const user1 = await User.findById(1);
const user2 = await User.findById(2);
const user3 = await User.findById(3);

// ✅ GOOD: Batch query
const users = await User.findByIds([1, 2, 3]);
```

## Algorithmic Issues

### Nested Loops (O(n²))

```typescript
// ❌ CRITICAL: O(n²) nested loop
function findDuplicates(arr: number[]): boolean {
  for (let i = 0; i < arr.length; i++) {
    for (let j = i + 1; j < arr.length; j++) {
      if (arr[i] === arr[j]) return true;
    }
  }
  return false;
}

// ✅ SAFE: O(n) with Set
function findDuplicates(arr: number[]): boolean {
  const seen = new Set();
  for (const item of arr) {
    if (seen.has(item)) return true;
    seen.add(item);
  }
  return false;
}
```

**Severity Mapping:**
- **P0**: O(n²) on large datasets (n > 10,000)
- **P1**: O(n²) on medium datasets (n > 1,000)
- **P2**: Suboptimal algorithm (O(n log n) vs O(n))
- **P3**: Minor algorithmic improvement

### String Concatenation in Loops

```typescript
// ❌ BAD: Creates many intermediate strings
let result = '';
for (let i = 0; i < 10000; i++) {
  result += i; // O(n²) - creates new string each time
}

// ✅ GOOD: Use array join
const parts = [];
for (let i = 0; i < 10000; i++) {
  parts.push(i);
}
const result = parts.join(''); // O(n)
```

### Wrong Data Structure

```typescript
// ❌ BAD: List for lookups
const userNames = ['alice', 'bob', 'charlie'];
function hasUser(name: string): boolean {
  return userNames.includes(name); // O(n) lookup!
}

// ✅ GOOD: Set for lookups
const userNames = new Set(['alice', 'bob', 'charlie']);
function hasUser(name: string): boolean {
  return userNames.has(name); // O(1) lookup!
}
```

**Severity Mapping:**
- **P0**: Wrong structure causes O(n²) performance
- **P1**: Wrong structure causes O(n) instead of O(1)
- **P2**: Suboptimal structure for access pattern

## Caching Issues

### Missing Cache

```typescript
// ❌ BAD: Expensive computation on every request
async function getUserStats(userId: number) {
  // Aggregates millions of rows every time!
  return await db.query(`
    SELECT COUNT(*), AVG(amount), MAX(amount)
    FROM orders
    WHERE user_id = $1
  `, [userId]);
}

// ✅ GOOD: Cache with TTL
async function getUserStats(userId: number) {
  const cached = await cache.get(`user:${userId}:stats`);
  if (cached) return JSON.parse(cached);

  const stats = await db.query(/* ... */);
  await cache.set(`user:${userId}:stats`, JSON.stringify(stats), 3600);
  return stats;
}
```

**Severity Mapping:**
- **P0**: Expensive operation on every hot path request
- **P1**: External API call without cache
- **P2**: Database query for static/reference data
- **P3**: Minor caching improvement

### Cache Invalidation

```typescript
// ❌ BAD: Cache never invalidated
async function getUser(userId: number) {
  const cached = await cache.get(`user:${userId}`);
  if (cached) return cached;
  // ... but cache is never updated when user changes!
}

// ✅ GOOD: Proper cache invalidation
async function updateUser(userId: number, data: any) {
  await db.update('users', data, { id: userId });
  await cache.del(`user:${userId}`); // Invalidate!
  await cache.del(`user:${userId}:stats`); // Invalidate related!
}
```

## Memory Issues

### Memory Leaks

```typescript
// ❌ CRITICAL: Unbounded cache growth
class Cache {
  private cache = new Map();

  set(key: string, value: any) {
    this.cache.set(key, value); // Never removes entries!
  }
}

// ✅ SAFE: Bounded cache with eviction
class Cache {
  private cache = new Map();
  private maxSize = 1000;

  set(key: string, value: any) {
    if (this.cache.size >= this.maxSize) {
      const firstKey = this.cache.keys().next().value;
      this.cache.delete(firstKey); // Evict oldest
    }
    this.cache.set(key, value);
  }
}

// ❌ BAD: Event listener never removed
button.addEventListener('click', handler);
// If button recreated, listener stays!

// ✅ GOOD: Clean up listeners
const handler = () => { /* ... */ };
button.addEventListener('click', handler);
// Later: button.removeEventListener('click', handler);
```

**Severity Mapping:**
- **P0**: Unbounded memory growth, will crash
- **P1**: Significant memory leak over time
- **P2**: Potential memory leak
- **P3**: Minor memory improvement

### Memory Inefficiency

```typescript
// ❌ BAD: Unnecessary data copying
function processLargeArray(arr: number[]) {
  const copy = [...arr]; // Copies entire array!
  const filtered = copy.filter(x => x > 0);
  return filtered;
}

// ✅ GOOD: Avoid unnecessary copies
function processLargeArray(arr: number[]) {
  return arr.filter(x => x > 0); // Operates on original
}
```

## I/O Issues

### Synchronous I/O

```typescript
// ❌ CRITICAL: Blocks event loop
const data = fs.readFileSync('/path/to/file.json');

// ✅ SAFE: Async I/O
const data = await fs.promises.readFile('/path/to/file.json');
```

**Severity Mapping:**
- **P0**: Blocks event loop on hot path
- **P1**: Synchronous I/O in user request
- **P2**: Suboptimal I/O pattern

### No Batching

```typescript
// ❌ BAD: Processes one by one
async function sendEmails(recipients: string[]) {
  for (const email of recipients) {
    await mailer.send(email); // N sequential calls!
  }
}

// ✅ GOOD: Batch operations
async function sendEmails(recipients: string[]) {
  await mailer.sendBatch(recipients); // 1 call!
}

// ✅ GOOD: Parallel with Promise.all
async function sendEmails(recipients: string[]) {
  await Promise.all(
    recipients.map(email => mailer.send(email))
  );
}
```

## CPU Hotspots

### Regex in Loop

```typescript
// ❌ BAD: Compiles regex on every iteration
function validateEmails(emails: string[]) {
  return emails.map(email => {
    const regex = /^[a-z0-9]+@[a-z0-9]+\.[a-z]+$/i; // Compiles every time!
    return regex.test(email);
  });
}

// ✅ GOOD: Compile once
const EMAIL_REGEX = /^[a-z0-9]+@[a-z0-9]+\.[a-z]+$/i;

function validateEmails(emails: string[]) {
  return emails.map(email => EMAIL_REGEX.test(email));
}
```

### Deep Cloning

```typescript
// ❌ BAD: Expensive deep clone
function process(obj: any) {
  const copy = JSON.parse(JSON.stringify(obj)); // Very slow!
  // ... modify copy
}

// ✅ GOOD: Avoid cloning if possible
function process(obj: any) {
  const result = { ...obj, modified: true }; // Shallow copy
  return result;
}
```

## Quick Reference

| Issue | Detection Pattern | Severity |
|-------|------------------|----------|
| N+1 Query | Query inside loop | P0 if hot path |
| Missing Index | WHERE on unindexed column | P0 if large table |
| O(n²) Loop | Nested loops over data | P0 if n > 10,000 |
| No Cache | Expensive op on every request | P0 if expensive |
| Memory Leak | Unbounded growth | P0 if crashes |
| Sync I/O | `readFileSync`, `execSync` | P0 if event loop |
| Regex Loop | `/pattern/` inside loop | P0 if many iterations |
