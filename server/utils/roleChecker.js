const { db } = require('../config/firebase');

const checkRole = (requiredRole) => async (req, res, next) => {
  try {
    const userDoc = await db.collection('user').doc(req.user.uid).get();
    if (!userDoc.exists) return res.status(403).json({ message: 'User not found' });

    const userData = userDoc.data();
    if (userData.role !== requiredRole) {
      return res.status(403).json({ message: 'Access denied' });
    }
    next();
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

module.exports = { checkRole };
