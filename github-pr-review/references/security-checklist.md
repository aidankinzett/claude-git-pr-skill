# Security Checklist

A comprehensive checklist for identifying security vulnerabilities during PR review.

## Injection Attacks

### SQL Injection

#### Critical Patterns
```typescript
// ❌ CRITICAL: Direct concatenation with user input
const query = `SELECT * FROM users WHERE id = ${userId}`;
const query = `SELECT * FROM users WHERE name = '${userName}'`;

// ✅ SAFE: Parameterized queries
const query = 'SELECT * FROM users WHERE id = $1';
await db.query(query, [userId]);

// ✅ SAFE: ORM with proper escaping
const user = await User.findBy({ id: userId });
```

#### Detection Checklist
- [ ] String concatenation in SQL queries
- [ ] Template literals with user input in queries
- [ ] Missing parameter binding
- [ ] Raw query execution without sanitization

**Severity Mapping:**
- **P0**: Direct concatenation with user input
- **P1**: Partial sanitization but still vulnerable
- **P2**: ORM misuse risks

### Command Injection

```typescript
// ❌ CRITICAL: Command injection risk
const output = exec(`ls ${userPath}`);
const result = spawn('cat', [userFile]);

// ✅ SAFE: Use proper APIs
const files = await fs.readdir(userPath);
const content = await fs.readFile(userFile);
```

**Severity Mapping:**
- **P0**: Direct command execution with user input
- **P1**: Partial sanitization

### XSS (Cross-Site Scripting)

```typescript
// ❌ CRITICAL: Stored XSS
div.innerHTML = userComment; // User comment stored and displayed

// ❌ CRITICAL: Reflected XSS
const query = new URLSearchParams(window.location.search);
div.textContent = query.get('name'); // Should use textContent!

// ✅ SAFE: Proper escaping
div.textContent = userComment;
div.innerText = userComment;

// ✅ SAFE: Sanitization library
div.innerHTML = DOMPurify.sanitize(userInput);
```

**Severity Mapping:**
- **P0**: Stored XSS (affects all users)
- **P1**: Reflected XSS (requires user interaction)
- **P2**: DOM-based XSS in specific scenarios

### NoSQL Injection

```typescript
// ❌ CRITICAL: NoSQL injection
const query = { $where: `this.username === '${username}'` };

// ✅ SAFE: Use proper operators
const query = { username: username };
```

## Authentication & Authorization

### Authentication Issues

#### Hardcoded Credentials
```typescript
// ❌ CRITICAL: Never do this
const API_KEY = 'sk-1234567890abcdef';
const DB_PASSWORD = 'admin123';

// ✅ SAFE: Environment variables
const API_KEY = process.env.API_KEY;
```

#### Password Hashing
```typescript
// ❌ BAD: Weak or no hashing
const hash = md5(password);
const hash = sha1(password);
const stored = password; // Plain text!

// ✅ SAFE: Strong hashing
const hash = await bcrypt.hash(password, 12);
const hash = await argon2.hash(password);
```

#### Session Management
```typescript
// ❌ BAD: No timeout
session.setMaxAge(Infinity);

// ❌ BAD: Predictable session IDs
const sessionId = Date.now().toString();

// ✅ SAFE: Proper session config
session.setMaxAge(3600000); // 1 hour
const sessionId = crypto.randomBytes(32).toString('hex');
```

### Authorization Issues

#### Missing Authentication Checks
```typescript
// ❌ CRITICAL: No auth check
app.delete('/api/users/:id', async (req, res) => {
  await User.delete(req.params.id); // Anyone can delete!
});

// ✅ SAFE: Check authentication
app.delete('/api/users/:id',
  authenticate,
  authorize('admin'),
  async (req, res) => {
    await User.delete(req.params.id);
  }
);
```

#### IDOR (Insecure Direct Object Reference)
```typescript
// ❌ CRITICAL: IDOR vulnerability
app.get('/api/orders/:id', async (req, res) => {
  const order = await Order.findById(req.params.id);
  res.json(order); // Returns any order, not just user's!
});

// ✅ SAFE: Verify ownership
app.get('/api/orders/:id',
  authenticate,
  async (req, res) => {
    const order = await Order.findOne({
      _id: req.params.id,
      userId: req.user.id // Verify ownership
    });
    if (!order) return res.status(404).json({ error: 'Not found' });
    res.json(order);
  }
);
```

#### Missing Role Checks
```typescript
// ❌ BAD: No role verification
app.post('/admin/settings', async (req, res) => {
  // Anyone can access admin settings!
});

// ✅ SAFE: Role-based access
app.post('/admin/settings',
  requireRole('admin'),
  async (req, res) => { }
);
```

## Data Security

### Sensitive Data Exposure

#### Logging Secrets
```typescript
// ❌ CRITICAL: Logging sensitive data
console.log('User login:', { email, password, apiKey });
logger.info('Payment:', req.body);

// ✅ SAFE: Sanitize logs
console.log('User login:', { email: maskEmail(email) });
logger.info('Payment:', {
  amount: req.body.amount,
  card: maskCard(req.body.cardNumber)
});
```

#### Error Messages
```typescript
// ❌ BAD: Exposes internal details
res.status(500).json({
  error: err.message,
  stack: err.stack, // Exposes internal structure!
  sql: err.sql // Exposes database schema!
});

// ✅ SAFE: Generic error for users
res.status(500).json({
  error: 'Internal server error'
});

// Log detailed error internally
logger.error(err);
```

#### HTTPS Enforcement
```typescript
// ❌ BAD: Allows HTTP
app.use((req, res, next) => next());

// ✅ SAFE: Force HTTPS
app.use((req, res, next) => {
  if (!req.secure && process.env.NODE_ENV === 'production') {
    return res.redirect('https://' + req.headers.host + req.url);
  }
  next();
});
```

### Cryptography

#### Weak Algorithms
```typescript
// ❌ CRITICAL: Weak algorithms
const hash = crypto.createHash('md5').update(data).digest('hex');
const encrypted = crypto.createCipheriv('des', key, iv);

// ✅ SAFE: Strong algorithms
const hash = crypto.createHash('sha256').update(data).digest('hex');
const encrypted = crypto.createCipheriv('aes-256-gcm', key, iv);
```

#### Key Management
```typescript
// ❌ CRITICAL: Hardcoded keys
const ENCRYPTION_KEY = '1234567890123456';

// ✅ SAFE: Environment variables
const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY;
if (!ENCRYPTION_KEY) throw new Error('ENCRYPTION_KEY required');
```

## Web Security

### CSRF Protection

```typescript
// ❌ BAD: No CSRF token
app.post('/api/transfer', (req, res) => {
  // Vulnerable to CSRF
});

// ✅ SAFE: CSRF token
import csrf from 'csurf';
const csrfProtection = csrf({ cookie: true });

app.post('/api/transfer', csrfProtection, (req, res) => {
  // Verify token
});
```

### SSRF Protection

```typescript
// ❌ CRITICAL: User controls URL
app.get('/api/fetch', async (req, res) => {
  const url = req.query.url;
  const data = await fetch(url); // Can fetch internal services!
  res.json(data);
});

// ✅ SAFE: URL whitelist
const ALLOWED_HOSTS = ['api.example.com'];

app.get('/api/fetch', async (req, res) => {
  const url = new URL(req.query.url);
  if (!ALLOWED_HOSTS.includes(url.hostname)) {
    return res.status(400).json({ error: 'Invalid host' });
  }
  const data = await fetch(url);
  res.json(data);
});
```

## Race Conditions

### Check-Then-Act
```typescript
// ❌ CRITICAL: Race condition
if (user.balance >= amount) {
  // Another transaction could happen here!
  user.balance -= amount;
  await user.save();
}

// ✅ SAFE: Atomic operation
await User.transaction(async (trx) => {
  const user = await User.forUpdate().where('id', userId);
  if (user.balance >= amount) {
    await User.update({ balance: user.balance - amount });
  }
});
```

## Quick Reference

| Vulnerability | P0 Example | Detection Method |
|---------------|-----------|------------------|
| SQL Injection | String concat in query | Look for `+` or `${` in SQL |
| XSS | innerHTML with user input | Search for `innerHTML` |
| Hardcoded Secrets | API keys in code | Search for `sk-`, `password =` |
| IDOR | No ownership check | Look for `req.params.id` direct use |
| CSRF | No token on POST | Check for CSRF middleware |
| SSRF | User-controlled URL | Look for `fetch(userUrl)` |
