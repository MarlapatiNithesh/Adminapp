const { db } = require('../config/firebase');

const checkRole = (requiredRole) => async (req, res, next) => {
  try {

    if (!req.user || !req.user.uid) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const userDoc = await db.collection('user').doc(req.user.uid).get();

    if (!userDoc.exists) {
      return res.status(403).json({ message: 'User not found' });
    }

    const userData = userDoc.data(); // ✅ FIX: get document data

    if (userData.role !== requiredRole) {
      return res.status(403).json({ message: 'Access denied' });
    }

    next();
  } catch (err) {
    console.error('checkRole error:', err);
    res.status(500).json({ message: err.message });
  }
};

module.exports = { checkRole };
