import jwt from 'jsonwebtoken';

const secret = () => process.env.JWT_SECRET || 'garigo_dev_secret';

export function signToken(payload, expiresIn = '30d') {
  return jwt.sign(payload, secret(), { expiresIn });
}

export function authRequired(roles = []) {
  return (req, res, next) => {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) return res.status(401).json({ error: 'Unauthorized' });
    try {
      const decoded = jwt.verify(token, secret());
      if (roles.length && !roles.includes(decoded.role)) {
        return res.status(403).json({ error: 'Forbidden' });
      }
      req.user = decoded;
      next();
    } catch {
      return res.status(401).json({ error: 'Invalid token' });
    }
  };
}
