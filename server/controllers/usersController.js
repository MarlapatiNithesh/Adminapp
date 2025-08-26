const { db } = require('../config/firebase');

const getAllUsers = async (req, res) => {
  try {
    const roleFilter = req.query.role;
    let query = db.collection('user');

    if (roleFilter) {
      query = query.where('role', '==', roleFilter);
    }

    const snapshot = await query.get();
    const users = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    res.status(200).json(users);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const deleteUser = async (req, res) => {
  try {
    const userId = req.params.id;
    await db.collection('user').doc(userId).delete();
    res.status(200).json({ message: 'User deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const updateUser = async (req, res) => {
  try {
    const userId = req.params.id;
    const updates = req.body;
    await db.collection('user').doc(userId).update(updates);
    res.status(200).json({ message: 'User updated successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

module.exports = {
  getAllUsers,
  deleteUser,
  updateUser,
};
