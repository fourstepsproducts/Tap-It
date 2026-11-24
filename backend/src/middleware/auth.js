const jwt = require('jsonwebtoken');

/**
 * Authentication middleware.
 * Strictly verifies JWT tokens against JWT_SECRET.
 * Rejects requests if JWT_SECRET is missing or insecure placeholder.
 */
const authMiddleware = (req, res, next) => {
  const secret = process.env.JWT_SECRET;

  if (!secret || secret === 'your_secret_key' || secret.trim() === '') {
    console.error('CRITICAL: JWT_SECRET is not properly configured.');
    return res.status(500).json({
      success: false,
      message: 'Server configuration error: Authentication secret not set.',
    });
  }

  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      message: 'Access denied. No authentication token provided.',
    });
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, secret);
    req.user = decoded;
    return next();
  } catch (err) {
    return res.status(401).json({
      success: false,
      message: 'Invalid or expired token.',
    });
  }
};

module.exports = authMiddleware;
